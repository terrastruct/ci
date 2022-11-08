#!/bin/sh

if [ "${_LIB:-}" ]; then
  return
fi
_LIB=1

. "$(dirname "$0")/rand.sh"
. "$(dirname "$0")/log.sh"
. "$(dirname "$0")/go.sh"

# ***
# git
# ***

set_git_base() {
  if [ -n "${GIT_BASE_DONE:-}" ]; then
    return
  fi

  if [ -n "${CI_ALL:-}" ]; then
    return
  fi

  if git show --no-patch --format=%s%n%b | grep -qiF '\[ci-all\]'; then
    return
  fi

  if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    git fetch --unshallow origin master
  fi

  # Unfortunately --grep searches the whole commit message but we just want the header
  # searched. Should fix by using grep directly later.
  export GIT_BASE="$(git log --merges --grep="Merge pull request" --grep="\[ci-base\]" --format=%h HEAD~1 | head -n1)"
  export GIT_BASE_DONE=1
  if [ -n "$GIT_BASE" ]; then
    echop make "GIT_BASE=$GIT_BASE"
  fi
}

is_changed() {
  set_git_base
  if [ -z "${GIT_BASE:-}" ]; then
    return
  fi

  ! git diff --quiet "$GIT_BASE" -- "$@" ||
    [ -n "$(git ls-files --other --exclude-standard -- "$@")" ]
}

set_changed_files() {
  set_git_base

  filter_exists() {
    while read -r p; do
      if [ -e "$p" ]; then
        printf '%s\n' "$p"
      fi
    done
  }

  if [ -n "${CHANGED_FILES:-}" ]; then
    return
  fi

  CHANGED_FILES=./.changed-files
  git ls-files --other --exclude-standard > "$CHANGED_FILES"
  if [ -n "${GIT_BASE:-}" ]; then
    git diff --relative --name-only "$GIT_BASE" | filter_exists >> "$CHANGED_FILES"
  else
    git ls-files >> "$CHANGED_FILES"
  fi
  export CHANGED_FILES
}

git_describe_ref() {
  TAG="$(git describe 2> /dev/null || true)"
  if [ -n "$TAG" ]; then
    _echo "$TAG"
  else
    git rev-parse --short HEAD
  fi
}

# ***
# make
# ***

_make() {
  if [ "${CI:-}" ]; then
    if ! is_changed .; then
      return
    fi
    if [ "${GITHUB_TOKEN:-}" ]; then
      git config --global credential.helper store
      cat > ~/.git-credentials <<EOF
https://cyborg-ts:$GITHUB_TOKEN@github.com
EOF
    fi
    git submodule update --init --recursive
  fi
  if [ -z "${MAKE_LOG:-}" ]; then
    CI_MAKE_ROOT=1
    export MAKE_LOG="./.make-log"
    set +e
    # runtty is necessary to allow make to write its output unbuffered. Otherwise the
    # output is printed in surges as the write buffer is exceeded rather than a continous
    # stream. Remove the runtty prefix to experience the laggy behaviour without it.
    runtty make -sj8 "$@" \
      | tee /dev/stderr "$MAKE_LOG" \
      | stripansi > "$MAKE_LOG.txt"
  else
    CI_MAKE_ROOT=0
    set +e
    make -sj8 "$@" 2>&1
  fi

  code="$?"
  set -e
  if [ "$code" -ne 0 ]; then
    notify "$code"
    return "$code"
  fi
  # make doesn't return a nonsuccess exit code on recipe failures.
  if <"$MAKE_LOG" grep -q 'make.* \*\*\* .* Error'; then
    notify 1
    return 1
  fi
  if [ -n "${CI:-}" ]; then
    # Make sure nothing has changed
    if ! git -c color.ui=always diff --exit-code; then
      notify 1
      return 1
    fi
  fi
  notify 0
}

# ***
# misc
# ***

search_up() {(
  file="$1"
  git_root="$(git rev-parse --show-toplevel)"
  while true; do
    if [ -e "$file" ]; then
      _echo "$file"
      return
    fi
    if [ "$PWD" = "$git_root" ]; then
      break
    fi
    cd ..
  done
  return 1
)}

# ***
# integrations
# ***

aws() {
  # Without the redirection aws's cli will write directly to /dev/tty bypassing prefix.
  command aws "$@" > /dev/stdout
}

notify() {
  if [ "$CI_MAKE_ROOT" -eq 0 -o -z "${CI:-}" ]; then
    return
  fi
  if [ -z "${SLACK_WEBHOOK_URL:-}" -a -z "${DISCORD_WEBHOOK_URL:-}" ]; then
    # Not all repos need CI failure notifications.
    return
  fi

  if [ -z "${GITHUB_RUN_ID:-}" ]; then
    # For testing.
    GITHUB_WORKFLOW=ci
    GITHUB_JOB=fmt
    GITHUB_REPOSITORY=terrastruct/src
    GITHUB_RUN_ID=3086720699
    GITHUB_JOB=all
  elif [ "$GITHUB_REF_PROTECTED" != true ]; then
    # We only want to notify on protected branch failures.
    return
  fi

  code="$1"
  if [ "$code" -eq 0 ]; then
    status=success
    emoji=🟢
  else
    status='failure'
    emoji=🛑
    if [ "${SLACK_WEBHOOK_URL:-}" ]; then
      status="$status <!here>"
    fi
  fi

  GITHUB_JOB_URL="$(curl -fsSL -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/jobs?per_page=100" | \
    jq -r ".jobs[] | select( .name == \"$GITHUB_JOB\") | .html_url")"
  if [ -z "$GITHUB_JOB_URL" ]; then
    status="failed to query github job URL <!here>"
    emoji=🛑
    GITHUB_JOB_URL="https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
  fi

  commit_sha="$(git rev-parse --short HEAD)"
  commit_title="$(git show --no-patch '--format=%s')"

  # We need to escape any & < > in $commit_title.
  # See https://api.slack.com/reference/surfaces/formatting#escaping
  commit_title="$(_echo "$commit_title" | sed -e 's/&/\&amp;/g' )"
  commit_title="$(_echo "$commit_title" | sed -e 's/</\&lt;/g' )"
  commit_title="$(_echo "$commit_title" | sed -e 's/>/\&gt;/g' )"

  # Three differences.
  # 1. @here doesn't work in discord code blocks but do in slack.
  # 2. URLs don't work in discord code blocks but do in slack.
  # 3. content vs text for the request JSON payload.
  # 4. Discord handles spacing in and around code blocks really weirdly. If $GITHUB_JOB_URL
  #    has a newline between it and the end of the code block, it's rendered as a separate
  #    paragraph instead of just below the code block.
  if [ "${DISCORD_WEBHOOK_URL:-}" ]; then
    msg="---"
    if [ "$code" -ne 0 ]; then
      msg="$msg @here"
    fi
    msg="$msg\`\`\`
$emoji $commit_sha - $commit_title | $GITHUB_WORKFLOW/$GITHUB_JOB: $status
\`\`\`$GITHUB_JOB_URL"
    json="{\"content\":$(printf %s "$msg" | jq -sR .)}"
    url="$DISCORD_WEBHOOK_URL"
  elif [ "${SLACK_WEBHOOK_URL:-}" ]; then
    msg="\`\`\`
$emoji $commit_sha - $commit_title | $GITHUB_WORKFLOW/$GITHUB_JOB: $status
   $GITHUB_JOB_URL
\`\`\`"
    json="{\"text\":$(printf %s "$msg" | jq -sR .)}"
    url="$SLACK_WEBHOOK_URL"
  fi
  sh_c curl -fsSL -X POST -H 'Content-type: application/json' --data "$json" "$url" > /dev/null
}

# ***
# job control
# ***

job_info() {
  _echo "$JOBS" | grep "$1"
}

wait_jobs() {
  JOBS="$(jobs -l)"
  for pid in $(jobs -p); do
    if ! wait "$pid"; then
      echoerr <<EOF
waiting on $pid failed:
  $(job_info "$pid")
EOF
    fi
  done
}
