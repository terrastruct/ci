#!/bin/sh
if [ "${LIB_FLAG-}" ]; then
  return 0
fi
LIB_FLAG=1

# flag_parse implements a robust flag parser.
#
# For a full fledge example see ../examples/date.sh
#
# It differs from getopts(1) in that long form options are supported. Currently the only
# deficiency is that short combined options are not supported like -xyzq. That would be
# interpreted as a single -xyzq flag. The other deficiency is lack of support for short
# flag syntax like -carg where the arg is not separated from the flag. This one is
# unfixable I believe unfortunately but for combined short flags I have opened
# https://github.com/terrastruct/ci/issues/6
#
# flag_parse stores state in $FLAG, $FLAGRAW, $FLAGARG and $FLAGSHIFT.
# FLAG contains the name of the flag without hyphens.
# FLAGRAW contains the name of the flag as passed in with hyphens.
# FLAGARG contains the argument for the flag if there was any.
#   If there was none, it will not be set.
# FLAGSHIFT contains the number by which the arguments should be shifted to
#   start at the next flag/argument
#
# After each call check $FLAG for the name of the parsed flag.
# If empty, then no more flags are left.
# Still, call shift "$FLAGSHIFT" in case there was a --
#
# If the argument for the flag is optional, then use ${FLAGARG-} to access
# the argument if one was passed. Use ${FLAGARG+x} = x to check if it was set.
# You only need to explicitly check if the flag was set if you care whether the user
# explicitly passed the empty string as the argument.
#
# Otherwise, call one of the flag_*arg functions:
#
# If a flag requires an argument, call flag_reqarg
#   - $FLAGARG is guaranteed to be set after.
# If a flag requires a non empty argument, call flag_nonemptyarg
#   - $FLAGARG is guaranteed to be set to a non empty string after.
# If a flag should not be passed an argument, call flag_noarg
#   - $FLAGARG is guaranteed to be unset after.
#
# And then shift "$FLAGSHIFT"
flag_parse() {
  case "${1-}" in
    -*=*)
      # Remove everything after first equal sign.
      FLAG="${1%%=*}"
      # Remove leading hyphens.
      FLAG="${FLAG#-}"; FLAG="${FLAG#-}"
      FLAGRAW="$(flag_fmt)"
      # Remove everything before first equal sign.
      FLAGARG="${1#*=}"
      FLAGSHIFT=1
      ;;
    -)
      FLAG=
      FLAGRAW=
      unset FLAGARG
      FLAGSHIFT=0
      ;;
    --)
      FLAG=
      FLAGRAW=
      unset FLAGARG
      FLAGSHIFT=1
      ;;
    -*)
      # Remove leading hyphens.
      FLAG="${1#-}"; FLAG="${FLAG#-}"
      FLAGRAW=$(flag_fmt)
      unset FLAGARG
      FLAGSHIFT=1
      if [ $# -gt 1 ]; then
        case "$2" in
          -)
            FLAGARG="$2"
            FLAGSHIFT=2
            ;;
          -*)
            ;;
          *)
            FLAGARG="$2"
            FLAGSHIFT=2
            ;;
        esac
      fi
      ;;
    *)
      FLAG=
      FLAGRAW=
      unset FLAGARG
      FLAGSHIFT=0
      ;;
  esac
  return 0
}

flag_reqarg() {
  if [ "${FLAGARG+x}" != x ]; then
    flag_errusage "flag $FLAGRAW requires an argument"
  fi
}

flag_nonemptyarg() {
  flag_reqarg
  if [ -z "$FLAGARG" ]; then
    flag_errusage "flag $FLAGRAW requires a non-empty argument"
  fi
}

flag_noarg() {
  if [ "$FLAGSHIFT" -eq 2 ]; then
    unset FLAGARG
    FLAGSHIFT=1
  elif [ "${FLAGARG+x}" = x ]; then
    # Means an argument was passed via equal sign as in -$FLAG=$FLAGARG
    flag_errusage "flag $FLAGRAW does not accept an argument"
  fi
}

flag_errusage() {
  caterr <<EOF
$1
Run with --help for usage.
EOF
  return 1
}

flag_fmt() {
  if [ "$(printf %s "$FLAG" | wc -c)" -eq 1 ]; then
    echo "-$FLAG"
  else
    echo "--$FLAG"
  fi
}
#!/bin/sh
if [ "${LIB_GIT-}" ]; then
  return 0
fi
LIB_GIT=1

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

git_assert_clean() {
  git ${TERM:+-c color.diff=always} diff --exit-code
}

filter_exists() {
  while read -r p; do
    if [ -e "$p" ]; then
      printf '%s\n' "$p"
    fi
  done
}

git_describe_ref() {
  TAG="$(git describe 2> /dev/null || true)"
  if [ -n "$TAG" ]; then
    _echo "$TAG"
  else
    git rev-parse --short HEAD
  fi
}

search_up() {
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
}

xargsd() {
  set_changed_files

  pattern="$1"
  shift

  < "$CHANGED_FILES" grep "$pattern" | hide xargs ${CI:+-r} -t -P16 "-n${XARGS_N:-256}" -- "$@"
}
#!/bin/sh
if [ "${LIB_JOB-}" ]; then
  return 0
fi
LIB_JOB=1

# This runs in a subshell so that we get output from the job even if it's shutting
# down due to a ctrl+c. Without the subshell, sed would be a job of the parent
# shell and so waitjobs would send SIGTERM to it.
#
# note: Unfortunately this leaks subprocesses when killed via a signal. Not sure how to
# remedy. I believe the code is 100% correct. Shell's seem quite buggy in their handling
# and propogating of signals. Not sure how to debug even without something like gdb and
# going through the source code of the shell too.
runjob() {(
  jobname=$1
  export JOBNAME=${JOBNAME+$JOBNAME/}$jobname
  shift
  if [ $# -eq 0 ]; then
    set "$jobname"
  fi

  if [ -n "${JOBFILTER-}" ]; then
    export SKIPDIR="$(mktemp -d)"
    trap 'rm -rf $SKIPDIR' EXIT
    # For each slash separated element of $JOBNAME, $JOBFILTER must match at its
    # corresponding element. In order to facilitate this, we split $JOBFILTER on / and then
    # reconstruct the regex up to the point of each / and match it against $JOBNAME.
    # If the constructed regex matches $JOBNAME every iteration until we run out of
    # elements in $JOBNAME to match against, then the job is not skipped.
    matches=$(_echo "$JOBNAME" | tr / '\n' | wc -l)
    i=1
    _echo "$JOBFILTER" | tr / $'\n' | while read -r regex; do
      if [ -z "$regex" ]; then
        regex='[^/]*'
      fi
      regex=${prev+$prev/}$regex
      if ! _echo "$JOBNAME" | grep -q "^$regex"; then
        touch "$SKIPDIR/skip"
        return 0
      fi
      if [ "$i" -eq "$matches" ]; then
        return 0
      fi
      prev=$regex
      i=$(( i + 1 ))
    done
    if [ -e "$SKIPDIR/skip" ]; then
      # Skip.
      return 0
    fi
  fi

  COLOR="$(get_rand_color "$jobname")"
  jobname="$(setaf "$COLOR" "$jobname")"
  _echo "$jobname^:" "$*"

  # We need to make sure we exit with a non zero exit if the command fails.
  # /bin/sh does not support -o pipefail unfortunately.
  job_tmpdir="$(mktemp -d)"
  stdout="$job_tmpdir/stdout"
  stderr="$job_tmpdir/stderr"
  mkfifo "$stdout"
  mkfifo "$stderr"

  # We add the prefix to all lines and remove any warning lines about recursive make.
  # We cannot silence these with -s which is unfortunate.
  sed -e "s#^#$jobname: #" -e "/make\[.\]: warning: -j/d" "$stdout" &
  sed -e "s#^#$jobname: #" -e "/make\[.\]: warning: -j/d" "$stderr" >&2 &

  start="$(awk 'BEGIN{srand(); print srand()}')"
  trap runjob_exittrap EXIT
  # For some reason without wrapping this in a subshell, the waitjobs in subjob
  # case_notequal_sign of ./lib/flags_test.sh freezes.
  ( eval "$*" >"$stdout" 2>"$stderr" )
)}

runjob_exittrap() {
  code="$?"
  end="$(awk 'BEGIN{srand(); print srand()}')"
  dur="$((end - start))"

  waitjobs_sigtrap
  if [ "$code" -eq 0 ]; then
    _echo "$jobname\$:" "$(setaf 2 success)" "($(echo_dur "$dur"))"
  else
    _echo "$jobname\$:" "$(setaf 1 failure)" "($(echo_dur "$dur"))"
  fi
  rm -r "$job_tmpdir"
}

waitjobs() {
  JOBS="$(jobs -l)"
  trap waitjobs_sigtrap INT TERM

  for pid in $(jobs -p); do
    if ! wait "$pid"; then
      caterr <<EOF
failed to wait on $pid:
$(_echo "$JOBS" | grep "$pid")
EOF
      FAILURE=1
    fi
  done
  if [ -n "${FAILURE-}" ]; then
    exit 1
  fi
}

waitjobs_sigtrap() {
  for pid in $(jobs -p); do
    kill "$pid" 2> /dev/null || true
  done
  waitjobs
}

job_parseflags() {
  while :; do
    flag_parse "$@"

    case "$FLAG" in
      run)
        flag_reqarg && shift "$FLAGSHIFT"
        export JOBFILTER="$FLAGARG"
        ;;
      h|help)
        cat <<EOF
usage: $0 [--run=jobregex]
EOF
        exit 0
        ;;
      '')
        shift "$FLAGSHIFT"
        break
        ;;
      *)
        flag_errusage "unrecognized flag $RAWFLAG"
        ;;
    esac
  done

  if [ $# -gt 0 ]; then
    flag_errusage "$0 does not accept any arguments"
  fi
}
#!/bin/sh
if [ "${LIB_LOG-}" ]; then
  return 0
fi
LIB_LOG=1

tput() {
  if [ -n "$TERM" ]; then
    command tput "$@"
  fi
}

setaf() {
  tput setaf "$1"
  shift
  printf '%s' "$*"
  tput sgr0
}

_echo() {
  printf '%s\n' "$*"
}

get_rand_color() {
  # 1-6 are regular and 9-14 are bright.
  # 1,2 and 9,10 are red and green but we use those for success and failure.
  pick "$*" 3 4 5 6 11 12 13 14
}

echop() {
  prefix="$1"
  shift

  if [ "$#" -gt 0 ]; then
    printfp "$prefix" "%s\n" "$*"
  else
    printfp "$prefix"
    printf '\n'
  fi
}

printfp() {(
  prefix="$1"
  shift

  if [ -z "${COLOR:-}" ]; then
    COLOR="$(get_rand_color "$prefix")"
  fi
  printf '%s' "$(setaf "$COLOR" "$prefix")"

  if [ $# -gt 0 ]; then
    printf ': '
    printf "$@"
  fi
)}

catp() {
  prefix="$1"
  shift

  sed "s/^/$(printfp "$prefix" '')/"
}

repeat() {
  char="$1"
  times="$2"
  seq -s "$char" "$times" | tr -d '[:digit:]'
}

strlen() {
  printf %s "$1" | wc -c
}

echoerr() {
  COLOR=1 echop err "$*" | humanpath>&2
}

caterr() {
  COLOR=1 catp err "$@" | humanpath >&2
}

printferr() {
  COLOR=1 printfp err "$@" | humanpath >&2
}

logp() {
  echop "$@" | humanpath >&2
}

logfp() {
  printfp "$@" | humanpath >&2
}

logpcat() {
  catp "$@" | humanpath >&2
}

log() {
  COLOR=5 logp log "$@"
}

logf() {
  COLOR=5 logfp log "$@"
}

logcat() {
  COLOR=5 logpcat log "$@"
}

warn() {
  COLOR=3 logp warn "$@"
}

warnf() {
  COLOR=3 logfp warn "$@"
}

sh_c() {
  COLOR=3 logp exec "$*"
  if [ -z "${DRY_RUN-}" ]; then
    eval "$@"
  fi
}

sudo_sh_c() {
  if [ "$(id -u)" -eq 0 ]; then
    sh_c "$@"
  elif command -v doas >/dev/null; then
    sh_c "doas $*"
  elif command -v sudo >/dev/null; then
    sh_c "sudo $*"
  elif command -v su >/dev/null; then
    sh_c "su root -c '$*'"
  else
    caterr <<EOF
This script needs to run the following command as root:
  $*
Please install doas, sudo, or su.
EOF
    exit 1
  fi
}

header() {
  logp "/* $1 */"
}

# humanpath replaces all occurrences of " $HOME" with " ~"
# and all occurrences of '$HOME' with the literal '$HOME'.
humanpath() {
  if [ -z "${HOME-}" ]; then
    cat
  else
    sed -e "s# $HOME# ~#g" -e "s#$HOME#\$HOME#g"
  fi
}

hide() {
  out="$(mktemp)"
  set +e
  "$@" >"$out" 2>&1
  code="$?"
  set -e
  if [ "$code" -eq 0 ]; then
    return
  fi
  cat "$out" >&2
  exit "$code"
}

echo_dur() {
  local dur=$1
  local h=$((dur/60/60))
  local m=$((dur/60%60))
  local s=$((dur%60))
  printf '%dh%dm%ds' "$h" "$m" "$s"
}

sponge() {
  dst="$1"
  tmp="$(mktemp)"
  cat > "$tmp"
  cat "$tmp" > "$dst"
}

stripansi() {
  # First regex gets rid of standard xterm escape sequences for controlling
  # visual attributes.
  # The second regex I'm not 100% sure, the reference says it selects the US
  # encoding but I'm not sure why that's necessary or why it always occurs
  # in tput sgr0 before the standard escape sequence.
  # See tput sgr0 | xxd
  sed -e $'s/\x1b\[[0-9;]*m//g' -e $'s/\x1b(.//g'
}

runtty() {
  case "$(uname)" in
    Darwin)
      script -q /dev/null "$@"
      ;;
    Linux)
      script -eqc "$*"
      ;;
    *)
      echoerr "runtty: unsupported OS $(uname)"
      return 1
  esac
}
#!/bin/sh
if [ "${LIB_MAKE-}" ]; then
  return 0
fi
LIB_MAKE=1

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
    if ! git_assert_clean; then
      notify 1
      return 1
    fi
  fi
  notify 0
}
#!/bin/sh
if [ "${LIB_MISC-}" ]; then
  return 0
fi
LIB_MISC=1

aws() {
  # Without the redirection aws's cli will write directly to /dev/tty bypassing prefix.
  command aws "$@" > /dev/stdout
}

docker_run() {
  sh_c docker run -it --rm \
    -v "$HOME:$HOME" \
    -w "$HOME" \
    -e HOME \
    -u "$(id -u):$(id -g)" \
    "$@"
}
#!/bin/sh
if [ "${LIB_NOTIFY-}" ]; then
  return 0
fi
LIB_NOTIFY=1

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
#!/bin/sh
if [ "${LIB_RAND-}" ]; then
  return 0
fi
LIB_RAND=1

rand() {
  seed="$1"
  range="$2"

  seed_file="$(mktemp)"
  _echo "$seed" | md5sum > "$seed_file"
  shuf -i "$range" -n 1 --random-source="$seed_file"
}

pick() {
  if ! command -v shuf >/dev/null || ! command -v md5sum >/dev/null; then
    eval "_echo \"\$3\""
    return
  fi

  seed="$1"
  shift
  i="$(rand "$seed" "1-$#")"
  eval "_echo \"\$$i\""
}
#!/bin/sh
if [ "${LIB_RELEASE-}" ]; then
  return 0
fi
LIB_RELEASE=1

goos() {
  case $1 in
    macos) echo darwin ;;
    *) echo $1 ;;
  esac
}

os() {
  uname=$(uname)
  case $uname in
    Linux) echo linux ;;
    Darwin) echo macos ;;
    FreeBSD) echo freebsd ;;
    *) echo "$uname" ;;
  esac
}

arch() {
  uname_m=$(uname -m)
  case $uname_m in
    aarch64) echo arm64 ;;
    x86_64) echo amd64 ;;
    *) echo "$uname_m" ;;
  esac
}

gh_repo() {
  gh repo view --json nameWithOwner --template '{{ .nameWithOwner }}'
}

manpath() {
  if command -v manpath >/dev/null; then
    command manpath
  elif man -w 2>/dev/null; then
    man -w
  else
    echo "${MANPATH-}"
  fi
}
#!/bin/sh
if [ "${LIB_TEST-}" ]; then
  return 0
fi
LIB_TEST=1

assert() {
  if [ $# -gt 2 ]; then
    exp="$3"
    got="$2"
  else
    eval "got=\$$1"
    exp="$2"
  fi
  if [ "$got" != "$exp" ]; then
    echoerr "unexpected $1"
    gitdiff_vars exp got
    return 1
  fi
}

assert_unset() {
  if [ "$(eval "_echo \"\${$1+x}\"")" = x ]; then
    eval "got=\$$1"
    echoerr "expected unset $1 but got: $got"
    return 1
  fi
}

gitdiff_vars() {
  tmpdir="$(mktemp -d)"
  eval "_echo \"\$$1\"" > "$tmpdir/$1"
  eval "_echo \"\$$2\"" > "$tmpdir/$2"
  set +e
  gitdiff "$tmpdir/$1" "$tmpdir/$2"
  code="$?"
  set -e
  if [ $code -eq 0 ]; then
    rm -r "$tmpdir"
  fi
  return $code
}

gitdiff() {(
  mkfifo "$tmpdir/fifo"
  cat "$tmpdir/fifo" | diff-highlight | tail -n +3 &
  trap waitjobs EXIT
  # 1. If TERM is set we want colors regardless of if output is a TTY.
  # 2. Use the best diff algorithm.
  # 3. Highlight trailing whitespace.
  GIT_CONFIG_NOSYSTEM=1 HOME= git ${TERM:+-c color.diff=always} diff \
    --diff-algorithm=histogram \
    --ws-error-highlight=all \
    --no-index "$@" >"$tmpdir/fifo"
)}
