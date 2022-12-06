#!/bin/sh
if [ "${LIB_CI-}" ]; then
  return 0
fi
LIB_CI=1

ci_go_fmt() {
	sh_c xargsd '\.go$' gofmt -s -w
	sh_c xargsd '\.go$' go run golang.org/x/tools/cmd/goimports@v0.3.0 \
		-w -local="$(go list -m)"
  if search_up go.mod; then
    sh_c go mod tidy
  fi
}

ci_go_lint() {
  go vet --composites=false ./...
}

ci_go_build() {
  go build ./...
}

ci_go_test() {
  go test "${@:-./...}"
}

ci_waitjobs() {
  if [ -z "${CI-}" ]; then
    waitjobs
    nofixups
    return 0
  fi

  capcode waitjobs
  if [ "$code" != 0 ]; then
    notify "$code"
    return "$code"
  fi
  capcode git_assert_clean
  if [ "$code" != 0 ]; then
    notify "$code"
    return "$code"
  fi
  notify 0
  return 0
}
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
# flag_parse exits with a non zero code when there are no more flags
# to be parsed. Still, call shift "$FLAGSHIFT" in case there was a --
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
      return 0
      ;;
    -)
      FLAGSHIFT=0
      return 1
      ;;
    --)
      FLAGSHIFT=1
      return 1
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
      return 0
      ;;
    *)
      FLAGSHIFT=0
      return 1
      ;;
  esac
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

ensure_git_base() {
  if [ "${GIT_BASE+x}" = x ]; then
    return
  fi

  if [ -n "${CI_FORCE-}" ]; then
    return
  fi

  if git show --no-patch --format=%s%n%b | grep -qiF '\[ci-all\]'; then
    return
  fi

  if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    git fetch --recurse-submodules=no --unshallow origin master
  fi

  if [ "$(git_commit_count)" -lt 2 ]; then
    GIT_BASE=
    export GIT_BASE
    return
  fi

  # Unfortunately --grep searches the whole commit message but we just want the header
  # searched. Should fix by using grep directly later.
  GIT_BASE="$(git log --grep="Merge pull request" --grep="\[ci-base\]" --format=%h HEAD | head -n1)"
  if [ "$GIT_BASE" = "$(git rev-parse --short HEAD)" ]; then
    if [ -z "$(git status -s)" ]; then
      GIT_BASE="$(git log --grep="Merge pull request" --grep="\[ci-base\]" --format=%h HEAD~1 | head -n1)"
    else
      GIT_BASE=HEAD
    fi
  fi
  export GIT_BASE
  if [ -n "$GIT_BASE" ]; then
    echop "GIT_BASE=$GIT_BASE"
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
  ! git diff --quiet "$GIT_BASE~1" -- "$@" ||
    [ -n "$(git ls-files --other --exclude-standard -- "$@")" ]
}

ensure_changed_files() {
  ensure_git_base

  if [ -n "${CHANGED_FILES-}" ]; then
    return
  fi

  CHANGED_FILES=$(mktempd)/changed-files
  trap changed_files_exittrap EXIT
  git ls-files --other --exclude-standard > "$CHANGED_FILES"
  if [ -n "${GIT_BASE-}" ]; then
    git diff --relative --name-only "$GIT_BASE" | filter_exists >> "$CHANGED_FILES"
  else
    git ls-files >> "$CHANGED_FILES"
  fi
  export CHANGED_FILES
  logpcat changed <"$CHANGED_FILES"
}

changed_files_exittrap() {
  rm -f "$CHANGED_FILES"
}

gitc() {
  if should_color; then
    command git -c color.diff=always "$@"
  else
    command git -c color.diff=never "$@"
  fi
}

git_assert_clean() {
  if should_color; then
    gitc diff --exit-code "$@"
  else
    gitc diff --exit-code "$@"
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

xargsd() {
  ensure_changed_files

  pattern="$1"
  shift

  < "$CHANGED_FILES" grep "$pattern" | hide xargs ${CI:+-r} -t -P16 "-n${XARGS_N:-256}" -- "$@"
}

nofixups() {
  ensure_git_base
  if [ "$(git_commit_count)" -lt 2 ]; then
    return
  fi
  commits="$(git log --grep='fixup!' --format=%h ${GIT_BASE:+"$GIT_BASE..HEAD"})"
  if [ -n "$commits" ]; then
    echo "$commits" | FGCOLOR=1 logpcat 'fixup detected'
    return 1
  fi
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
  localfiles="$(mktempd)/local_files"

  sh_c ssh "$REMOTE_HOST" "'mkdir -p \"$to\"'"
  sh_c ssh "$REMOTE_HOST" "'cd \"$to\" && git init'"
  sh_c git push "$REMOTE_HOST:$to"
  sh_c git ls-files --exclude-standard --cached --other > "$localfiles"
  sh_c rsync --archive --human-readable --delete --delete-missing-args \
    --files-from="$localfiles" ./ "$REMOTE_HOST:$to/"
)}
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

  if ! runjob_filter; then
    return 0
  fi

  should_color || true
  export COLOR=$__COLOR
  FGCOLOR="$(get_rand_color "$jobname")"
  echop "$jobname^" "$*"

  # We need to make sure we return with a non zero code if the command fails.
  # /bin/sh does not support -o pipefail unfortunately.
  job_tmpdir="$(mktempd)"
  stdout="$job_tmpdir/stdout"
  stderr="$job_tmpdir/stderr"
  mkfifo "$stdout"
  mkfifo "$stderr"

  # We add the prefix to all lines and remove any warning lines about recursive make.
  # We cannot silence these with -s which is unfortunate.
  sed -e "s#^#$(echop "$jobname"): #" -e "/make\[.\]: warning: -j/d" "$stdout" &
  # This intentionally does not output to our stderr, it becomes our stdout.
  sed -e "s#^#$(echop "$jobname"): #" -e "/make\[.\]: warning: -j/d" "$stderr" &

  start="$(awk 'BEGIN{srand(); print srand()}')"
  trap runjob_exittrap EXIT
  # For some reason without wrapping this in a subshell, the waitjobs in subjob
  # case_notequal_sign of ./lib/flags_test.sh freezes.
  ( eval "$*" >"$stdout" 2>"$stderr" )
)}

runjob_filter() {
  if [ -z "${JOBFILTER-}" ]; then
    return 0
  fi

  tmpdir="$(mktempd)"
  # For each slash separated element of $JOBNAME, $JOBFILTER must match at its
  # corresponding element. In order to facilitate this, we split $JOBFILTER on / and then
  # reconstruct the regex up to the point of each / and match it against $JOBNAME.
  # If the constructed regex matches $JOBNAME every iteration until we run out of
  # elements in $JOBNAME to match against, then the job is not skipped.
  echo "$JOBNAME" | tr / '\n' > "$tmpdir/jobname"
  echo "$JOBFILTER" | tr / '\n' > "$tmpdir/jobfilter"
  jobname_count=$(<"$tmpdir/jobname" wc -l)
  jobfilter_count=$(<"$tmpdir/jobfilter" wc -l)
  if [ "$jobname_count" -lt "$jobfilter_count" ]; then
    min=$jobname_count
  else
    min=$jobfilter_count
  fi
  for i in $(seq "$min"); do
    job_el=$(sed -n "${i}p" "$tmpdir/jobname")
    regex_el=$(sed -n "${i}p" "$tmpdir/jobfilter")
    if ! printf %s "$job_el" | grep -Eq "$regex_el"; then
      return 1
    fi
  done
  return 0
}

runjob_exittrap() {
  code="$?"
  end="$(awk 'BEGIN{srand(); print srand()}')"
  dur="$((end - start))"

  waitjobs_sigtrap
  if [ "$code" -eq 0 ]; then
    echop "$jobname\$" "$(setaf 2 success)" "($(echo_dur "$dur"))"
  else
    echop "$jobname\$" "$(setaf 1 failure)" "($(echo_dur "$dur"))"
  fi
  temp_exittrap
}

waitjobs() {
  wait_tmpdir="$(mktempd)"
  jobs -l > "$wait_tmpdir/jobsl"
  trap waitjobs_sigtrap INT TERM

  jobs -p > "$wait_tmpdir/jobsp"
  for pid in $(cat "$wait_tmpdir/jobsp"); do
    if ! wait "$pid"; then
      caterr <<EOF
failed to wait on $pid:
$(<"$wait_tmpdir/jobsl" grep "$pid")
EOF
      FAILURE=1
    fi
  done
  if [ -n "${FAILURE-}" ]; then
    return 1
  fi
}

waitjobs_sigtrap() {
  for pid in $(jobs -p); do
    kill "$pid" 2> /dev/null || true
  done
  waitjobs
}

job_parseflags() {
  while flag_parse "$@"; do
    case "$FLAG" in
      h|help)
        cat <<EOF
usage: $0 [-x] jobregex

-x
  Equivalent to DEBUG=1
EOF
        return 1
        ;;
      x)
        flag_noarg && shift "$FLAGSHIFT"
        set -x
        export DEBUG=1
        ;;
      *)
        flag_errusage "unrecognized flag $FLAGRAW"
        ;;
    esac
  done
  shift "$FLAGSHIFT"

  if [ $# -gt 0 ]; then
    JOBFILTER=$(strjoin / "$@")
    export JOBFILTER
  fi
}

# See https://unix.stackexchange.com/questions/22044/correct-locking-in-shell-scripts
lockfile() {
  LOCKFILE=$1
  LOCKFILE_PID=$(mktempd)/pid
  echo "pid $$" > $LOCKFILE_PID
  if [ -n "${LOCKFILE_FORCE-}" ]; then
    unlockfile_ssh
  fi
  if ln "$LOCKFILE_PID" "$LOCKFILE"; then
    return 0
  else
    echoerr "$LOCKFILE locked by $(cat "$LOCKFILE")"
    rm "$LOCKFILE_PID"
    return 1
  fi
  trap unlockfile EXIT
}

unlockfile() {
  rm -f "$LOCKFILE_PID" "$LOCKFILE"
}

lockfile_ssh() {
  LOCKHOST=$1
  LOCKFILE=$2
  LOCKFILE_PID=$(ssh "$LOCKHOST" mktemp)
  if [ -n "${LOCKFILE_FORCE-}" ]; then
    unlockfile_ssh
  fi
  ssh "$LOCKHOST" echo "ssh $USER@$(hostname)" \> "$LOCKFILE_PID"
  capcode ssh "$LOCKHOST" ln "$LOCKFILE_PID" "$LOCKFILE"
  if [ $code -ne 0 ]; then
    echoerr "$LOCKFILE locked by $(ssh "$LOCKHOST" cat "$LOCKFILE")"
    ssh "$LOCKHOST" rm "$LOCKFILE_PID"
    return 1
  fi
  trap unlockfile_ssh EXIT
}

unlockfile_ssh() {
  ssh "$LOCKHOST" rm -f "$LOCKFILE_PID" "$LOCKFILE"
}
#!/bin/sh
if [ "${LIB_LOG-}" ]; then
  return 0
fi
LIB_LOG=1

if [ -n "${DEBUG-}" ]; then
  set -x
fi

tput() {
  if should_color; then
    TERM=${TERM:-xterm-256color} command tput "$@"
  fi
}

should_color() {
  if [ -n "${COLOR-}" ]; then
    if [ "$COLOR" = 1 -o "$COLOR" = true ]; then
      _COLOR=1
      __COLOR=1
      return 0
    elif [ "$COLOR" = 0 -o "$COLOR" = false ]; then
      _COLOR=
      __COLOR=0
      return 1
    else
      printf '$COLOR must be 0, 1, false or true but got %s\n' "$COLOR" >&2
    fi
  fi

  if [ -t 1 -a "${TERM-}" != dumb ]; then
    _COLOR=1
    __COLOR=1
    return 0
  else
    _COLOR=
    __COLOR=0
    return 1
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
  if [ "${TERM_COLORS+x}" != x ]; then
    TERM_COLORS=""
    export TERM_COLORS
    ncolors=$(TERM=${TERM:-xterm-256color} command tput colors)
    if [ "$ncolors" -ge 8 ]; then
      # 1-6 are regular
      TERM_COLORS="$TERM_COLORS 1 2 3 4 5 6"
    elif [ "$ncolors" -ge 16 ]; then
      # 9-14 are bright.
      TERM_COLORS="$TERM_COLORS 9 10 11 12 13 14"
    fi
  fi
  pick "$*" $TERM_COLORS
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

  _FGCOLOR=${FGCOLOR:-$(get_rand_color "$prefix")}
  should_color || true
  if [ $# -eq 0 ]; then
    printf '%s' "$(COLOR=$__COLOR setaf "$_FGCOLOR" "$prefix")"
  else
    printf '%s: %s\n' "$(COLOR=$__COLOR setaf "$_FGCOLOR" "$prefix")" "$(printf "$@")"
  fi
)}

catp() {
  prefix="$1"
  shift

  should_color || true
  sed "s/^/$(COLOR=$__COLOR printfp "$prefix" '')/"
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
  FGCOLOR=1 logp err "$*"
}

caterr() {
  FGCOLOR=1 logpcat err "$@"
}

printferr() {
  FGCOLOR=1 logfp err "$@"
}

logp() {
  should_color >&2 || true
  COLOR=$__COLOR echop "$@" | humanpath >&2
}

logfp() {
  should_color >&2 || true
  COLOR=$__COLOR printfp "$@" | humanpath >&2
}

logpcat() {
  should_color >&2 || true
  COLOR=$__COLOR catp "$@" | humanpath >&2
}

log() {
  FGCOLOR=5 logp log "$@"
}

logf() {
  FGCOLOR=5 logfp log "$@"
}

logcat() {
  FGCOLOR=5 logpcat log "$@"
}

warn() {
  FGCOLOR=3 logp warn "$@"
}

warnf() {
  FGCOLOR=3 logfp warn "$@"
}

warncat() {
  FGCOLOR=3 logpcat warn "$@"
}

sh_c() {
  FGCOLOR=3 logp exec "$*"
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
Unable to run the following command as root:
  $*
Please install doas, sudo, or su.
EOF
    return 1
  fi
}

header() {
  FGCOLOR=${FGCOLOR:-4} logp "/* $1 */"
}

bigheader() {
  set -- "$(echo "$*" | sed "s/^/ * /")"
  FGCOLOR=${FGCOLOR:-3} logp "/**
$*
 **/"
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
  out="$(mktempd)/hideout"
  capcode "$@" >"$out" 2>&1
  if [ "$code" -eq 0 ]; then
    return
  fi
  cat "$out" >&2
  return "$code"
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
  tmp="$(mktempd)/sponge"
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

capcode() {
  set +e
  "$@"
  code=$?
  set -e
}

strjoin() {
  (IFS="$1"; shift; echo "$*")
}
#!/bin/sh
if [ "${LIB_MAKE-}" ]; then
  return 0
fi
LIB_MAKE=1

_make() {
  if [ -n "${CI-}" ] && ! is_changed .; then
    return
  fi
  if [ -z "${CI_MAKE_ROOT-}" ]; then
    CI_MAKE_ROOT=1
  else
    CI_MAKE_ROOT=0
  fi

  ensure_git_base
  capcode make -sj8 "$@"
  if [ "$code" != 0 ]; then
    notify "$code"
    return "$code"
  fi
  ci_waitjobs
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
  sh_c docker run --rm \
    -v "$HOME:$HOME" \
    -w "$HOME" \
    -e HOME \
    -e TERM \
    -e COLOR \
    -u "$(id -u):$(id -g)" \
    "$@"
}

pandoc_toc() {(
  if [ -n "${CI-}" ] && ! command -v pandoc >/dev/null; then
    VERSION=2.19.2
    ARCH=$(arch)
    export DEBIAN_FRONTEND=noninteractive
    sh_c curl -fssLO "https://github.com/jgm/pandoc/releases/download/$VERSION/pandoc-$VERSION-1-$ARCH.deb"
    sh_c sudo dpkg -i "pandoc-$VERSION-1-$ARCH.deb" >&2
    sh_c rm -f "pandoc-$VERSION-1-$ARCH.deb"
  fi
  pandoc --wrap=none -s --toc --from gfm --to gfm | awk '/-/{f=1} {if (!NF) exit; print}'
)}

tocsubst() {
  while flag_parse "$@"; do
    case "$FLAG" in
      h|help)
        cat <<EOF
usage: tocsubst [--skip n] README.md
EOF
        return 0
        ;;
      skip)
        flag_nonemptyarg && shift "$FLAGSHIFT"
        SKIP=$FLAGARG
        ;;
      *)
        flag_errusage "unrecognized flag $FLAGRAW"
        ;;
    esac
  done
  shift "$FLAGSHIFT"

  SKIP=${SKIP:-0}

  TOC=$(<"$1" pandoc_toc)
  if [ "$SKIP" -gt 0 ]; then
    TOC=$(echo "$TOC" | sed -E -e "/^ {0,$(((SKIP-1)*2))}-/d" -e "s/^ {0,$((SKIP*2))}//")
  fi
  TOC_START=$(<"$1" grep -Fn '<!-- toc -->' | cut -d: -f1 | head -n1)
  BEFORE_TOC=$(<"$1" head -n"$((TOC_START))")
  AFTER_TOC=$(<"$1" tail +"$((TOC_START+1))")
  TOC_END=$(echo "$AFTER_TOC" | grep -nm 1 '^$' | cut -d: -f1 | head -n1)
  TOC_END=$((TOC_START+TOC_END))
  AFTER_TOC=$(<"$1" tail +"$TOC_END")
  echo "$BEFORE_TOC" >"$1"
  echo "$TOC" >>"$1"
  echo "$AFTER_TOC" >>"$1"
}
#!/bin/sh
if [ "${LIB_NOTIFY-}" ]; then
  return 0
fi
LIB_NOTIFY=1

notify() {
  if [ "${CI_MAKE_ROOT-}" = 0 -o -z "${CI:-}" ]; then
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
  if [ -n "${DISCORD_WEBHOOK_URL-}" ]; then
    msg=""
    if [ "$code" -ne 0 ]; then
      msg="$msg @here"
    fi
    msg="$msg\`\`\`
$emoji $commit_sha - $commit_title | $GITHUB_WORKFLOW/$GITHUB_JOB: $status
\`\`\`<$GITHUB_JOB_URL>"
    json="{\"content\":$(printf %s "$msg" | jq -sR .)}"
    url="$DISCORD_WEBHOOK_URL"
  elif [ -n "${SLACK_WEBHOOK_URL-}" ]; then
    msg="\`\`\`
$emoji $commit_sha - $commit_title | $GITHUB_WORKFLOW/$GITHUB_JOB: $status
   $GITHUB_JOB_URL
\`\`\`"
    json="{\"text\":$(printf %s "$msg" | jq -sR .)}"
    url="$SLACK_WEBHOOK_URL"
  fi
  sh_c curl -fsSL -X POST -H 'Content-type:application/json' --data "'$json'" "$url" > /dev/null
}
#!/bin/sh
if [ "${LIB_RAND-}" ]; then
  return 0
fi
LIB_RAND=1

pick() {
  seed="$1"
  shift

  seed_file="$(mktempd)/pickseed"

  # We add 32 more bytes to the seed file for sufficient entropy. Otherwise both Cygwin's
  # and MinGW's sort for example complains about the lack of entropy on stderr and writes
  # nothing to stdout. I'm sure there are more platforms that would too.
  #
  # We also limit to a max of 32 bytes as otherwise macOS's sort complains that the random
  # seed is too large. Probably more platforms too.
  (echo "$seed" && echo "================================") | head -c32 >"$seed_file"

  while [ $# -gt 0 ]; do
    echo "$1"
    shift
  done \
    | sort --sort=random --random-source="$seed_file" \
    | head -n1
}
#!/bin/sh
if [ "${LIB_RELEASE-}" ]; then
  return 0
fi
LIB_RELEASE=1

ensure_goos() {
  if [ -n "${GOOS-}" ]; then
    return
  fi
  ensure_os
  case "$OS" in
    macos) export GOOS=darwin;;
    *) export GOOS=$OS;;
  esac
}

ensure_goarch() {
  if [ -n "${GOARCH-}" ]; then
    return
  fi
  ensure_arch
  case "$ARCH" in
    *) export GOARCH=$ARCH;;
  esac
}

ensure_os() {
  if [ -n "${OS-}" ]; then
    return
  fi
  uname=$(uname)
  case $uname in
    Linux) OS=linux;;
    Darwin) OS=macos;;
    FreeBSD) OS=freebsd;;
    CYGWIN_NT*|MINGW32_NT*) OS=windows;;
    *) OS=$uname;;
  esac
}

ensure_arch() {
  if [ -n "${ARCH-}" ]; then
    return
  fi
  uname_m=$(uname -m)
  case $uname_m in
    aarch64) ARCH=arm64;;
    x86_64) ARCH=amd64;;
    *) ARCH=$uname_m;;
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

is_writable_dir() {
  # If it can be created, we can use it.
  sh_c "mkdir -p '$1' 2>/dev/null"
}

ensure_prefix() {
  if [ -n "${PREFIX-}" ]; then
    return
  fi
  # The reason for checking whether bin is writable is that on macOS you have /usr/local
  # owned by root but you don't need root to write to its subdirectories which is all we
  # need to do.
  if ! is_writable_dir "/usr/local/bin"; then
    # This also handles M1 Mac's which do not allow modifications to /usr/local even
    # with sudo.
    PREFIX=$HOME/.local
  else
    PREFIX=/usr/local
  fi
}

ensure_prefix_sh_c() {
  ensure_prefix

  sh_c="sh_c"
  # The reason for checking whether bin is writable is that on macOS you have /usr/local
  # owned by root but you don't need root to write to its subdirectories which is all we
  # need to do.
  if ! is_writable_dir "$PREFIX/bin"; then
    sh_c="sudo_sh_c"
  fi
}
#!/bin/sh
if [ "${LIB_TEMP-}" ]; then
  return 0
fi
LIB_TEMP=1

ensure_tmpdir() {
  if [ -n "${_TMPDIR-}" ]; then
    return
  fi

  _TMPDIR=$(mktemp -d)
  export _TMPDIR
  trap temp_exittrap EXIT
}

temp_exittrap() {
  if [ -n "${_TMPDIR-}" ]; then
    rm -r "$_TMPDIR"
  fi
}

temppath() {
  ensure_tmpdir
  while true; do
    temppath=$_TMPDIR/$(</dev/urandom head -c8 | base64)
    if [ ! -e "$temppath" ]; then
      echo "$temppath"
      return
    fi
  done
}

mktempd() {
  tp=$(temppath)
  mkdir -p "$tp"
  echo "$tp"
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
    testdiff_vars exp got
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

testdiff_vars() {
  tmpdir="$(mktempd)/testdiff_vars"
  eval "_echo \"\$$1\"" > "$tmpdir/$1"
  eval "_echo \"\$$2\"" > "$tmpdir/$2"
  capcode testdiff "$tmpdir/$1" "$tmpdir/$2"
  if [ $code -eq 0 ]; then
    rm -r "$tmpdir"
  fi
  return $code
}

testdiff() {
  should_color || true
  _f() {
    # 1. If _COLOR is set we want colors.
    # 2. Use the best diff algorithm.
    # 3. Highlight trailing whitespace.
    git_pure diff \
      --diff-algorithm=histogram \
      --ws-error-highlight=all \
      --no-index "$@"
  }
  # note: Even though we set diff-highlight in the global git config in git_pure,
  # we still have to manually use diff-highlight here as git won't use its pager as
  # we're not sending to a tty.
  if command -v diff-highlight >/dev/null; then
    _f "$@" | diff-highlight | tail -n +3
  else
    _f "$@" | tail -n +3
  fi
}
