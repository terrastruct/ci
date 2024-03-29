#!/bin/sh
if [ "${LIB_GIT-}" ]; then
  return 0
fi
LIB_GIT=1
. ./log.sh
. ./release.sh
. ./temp.sh

ensure_git_base() {
  if [ "${GIT_BASE+x}" = x ]; then
    return
  fi

  if [ -n "${CI_FORCE-}" ] || [ "$(git_commit_count)" -lt 1 ]; then
    export GIT_BASE=
    FGCOLOR=4 echop "GIT_BASE="
    return
  fi

  if git show --no-patch --format=%s%n%b | grep -qF '[ci-force]'; then
    export CI_FORCE=1
    export GIT_BASE=
    FGCOLOR=4 echop "GIT_BASE="
    return
  fi

  if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    # Without --recurse-submodules, git fetch will sometimes throw errors like
    # fatal: remote error: upload-pack: not our ref a1eddf1ed342a9d9fb1942c0d03bf375ba7f6496
    # when fetching submodules.
    git fetch --recurse-submodules=no --unshallow
  fi

  if [ "$(git_commit_count)" -lt 2 ]; then
    export GIT_BASE=
    FGCOLOR=4 echop "GIT_BASE="
    return
  fi

  GIT_BASE="$(git log --grep="Merge pull request" --grep="\[ci-base\]" --grep="\[ci-force\]" --format=%h HEAD | head -n1)"
  if [ "$GIT_BASE" = "$(git rev-parse --short HEAD)" ]; then
    if [ -z "$(git status -s)" ]; then
      GIT_BASE="$(git log --grep="Merge pull request" --grep="\[ci-base\]" --grep="\[ci-force\]" --format=%h HEAD~1 | head -n1)"
    else
      GIT_BASE=HEAD
    fi
  fi
  export GIT_BASE
  if [ -n "$GIT_BASE" ]; then
    FGCOLOR=4 echop "GIT_BASE=$GIT_BASE"
  fi
}

is_changed() {
  ensure_git_base
  if [ -z "${GIT_BASE-}" ]; then
    return
  fi

  if [ "$(git_commit_count)" -lt 2 ]; then
    return
  fi
  ! git diff --quiet "$GIT_BASE" -- "$@" ||
    [ -n "$(git ls-files --other --exclude-standard -- "$@")" ]
}

ensure_changed_files() {
  ensure_git_base

  if [ -n "${CHANGED_FILES-}" ]; then
    return
  fi

  CHANGED_FILES=$(mktempd)/changed-files
  (
    git ls-files --other --exclude-standard > "$CHANGED_FILES"
    if [ -n "${GIT_BASE-}" ]; then
      git diff --relative --name-only "$GIT_BASE" | filter_exists >> "$CHANGED_FILES"
    else
      git ls-files >> "$CHANGED_FILES"
    fi
  )
  if [ -z "${CI_FORCE-}" ]; then
    logpcat changed <"$CHANGED_FILES"
  fi
}

gitc() {
  if should_color; then
    command git -c color.diff=always "$@"
  else
    command git -c color.diff=never "$@"
  fi
}

git_assert_clean() {
  diff=$(mktempd)/diff
  if should_color; then
    capcode git -c color.diff=always diff --exit-code "$@" >"$diff"
  else
    capcode git -c color.diff=never diff --exit-code "$@" >"$diff"
  fi
  if [ "$code" -ne 0 ]; then
    echoerr "some files need to be formatted or regenerated"
    cat "$diff" >&2
    return "$code"
  fi
}

filter_exists() {
  while read -r p; do
    if [ -e "$p" ]; then
      printf '%s\n' "$p"
    fi
  done
}

git_describe_ref() {
  TAG="$(git describe --exact-match 2> /dev/null || true)"
  if [ -n "$TAG" ]; then
    _echo "$TAG"
  else
    git rev-parse --short HEAD
  fi
}

# subshell for cd ..
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

xargs() {
  ensure_os
  if [ "$OS" = linux ]; then
    r_flag=1
  fi
  command xargs ${r_flag:+-r} -t -n"${XARGS_N:-256}" -- "$@"
}

xargsd() {
  ensure_changed_files
  pattern="$1"
  shift

  <"$CHANGED_FILES" grep "$pattern" | xargs "$@"
}

nofixups() {
  ensure_git_base
  if [ "$(git_commit_count)" -lt 1 ]; then
    return
  fi

  commits="$(git log --grep='fixup!' --format=%h ${GIT_BASE:+"$GIT_BASE..HEAD"})"
  if [ -n "$commits" ]; then
    echo "$commits" | FGCOLOR=1 logpcat 'fixup detected'
    return 1
  fi
}

ensure_signed() {
  ensure_git_base
  if [ "$(git_commit_count)" -lt 1 ]; then
    return
  fi

  setup_allowed_signers
  # look for signature status N: no signature (verification done by github)
  if [ ! "$(git log --format="%G?" ${GIT_BASE:+"$GIT_BASE..HEAD"} | grep "N")" ]; then
    return
  fi
  # print the hash and summary of the unsigned commits
  echo "$(git log --format="%G? %h %s" ${GIT_BASE:+"$GIT_BASE..HEAD"} | grep "^N " | cut -d " " -f 2- )" | FGCOLOR=1 logpcat 'found unsigned commit'
  return 1
}

setup_allowed_signers() {
  # we only care if a signature is present (github will verify) so we don't need any entries,
  # but "gpg.ssh.allowedSignersFile needs to be configured and exist for ssh signature verification"
  if git config --get gpg.ssh.allowedSignersFile >/dev/null; then
    return
  fi
  allowed_signers=".emptyAllowedSigners"
  touch $allowed_signers
  git config --local gpg.ssh.allowedSignersFile "$allowed_signers"
}

git_commit_count() {
  # macOS sh is buggy and requires the subshell here.
  (git rev-list HEAD --count 2>/dev/null) || echo 0
}

configure_github_token() {
  git config --global credential.helper store
  cat > ~/.git-credentials <<EOF
https://cyborg-ts:$GITHUB_TOKEN@github.com
EOF
}

git_pure() {
  if [ -z "${GIT_CONFIG_PURE-}" ]; then
    GIT_CONFIG_PURE="$(mktempd)/gitconfig-pure"
    export GIT_CONFIG_PURE
  fi

  if [ -z "${_GIT_CONFIG_PURE-}" ]; then
    if command -v diff-highlight >/dev/null; then
      GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global pager.log 'diff-highlight | less'
      GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global pager.show 'diff-highlight | less'
      GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global pager.diff 'diff-highlight | less'
    fi
    GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global init.defaultBranch master
    GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global user.name "Cyborg Tstruct"
    GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE command git config --global user.email "info+cyborg@terrastruct.com"
    export _GIT_CONFIG_PURE=1
  fi
  GIT_CONFIG_GLOBAL=$GIT_CONFIG_PURE gitc "$@"
}

gitsync() {(
  REMOTE_HOST=$1
  to=$2

  ssh "$REMOTE_HOST" sh <<EOF
set -eu
mkdir -p "$to"
cd "$to"
git init
EOF
  sh_c git push -f "$REMOTE_HOST:$to" HEAD:_gitsync
  ssh "$REMOTE_HOST" sh <<EOF
set -eu
mkdir -p "$to"
cd "$to"
git init
git checkout -qf "$(git rev-parse --short HEAD)"
git add --all
git reset --hard HEAD
git reset
git submodule update --init
EOF
  localfiles="$(mktempd)/local_files"
  sh_c git ls-files --exclude-standard --cached --other >"$localfiles"
  sh_c rsync --archive --human-readable --delete --delete-missing-args \
    --files-from="$localfiles" ./ "$REMOTE_HOST:$to/"
)}
