#!/bin/sh
if [ "${LIB_JOB-}" ]; then
  return 0
fi
LIB_JOB=1
. ./log.sh
. ./flag.sh

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

# See https://unix.stackexchange.com/questions/22044/correct-locking-in-shell-scripts
lockfile() {
  LOCKFILE=$1
  LOCKFILE_PID=$(mktemp)
  if [ -n "${LOCKFILE_FORCE-}" ]; then
    unlockfile_ssh
  fi
  echo "pid $$" > $LOCKFILE_PID
  if ln "$LOCKFILE_PID" "$LOCKFILE"; then
    return 0
  else
    echoerr "$LOCKFILE locked by $(cat "$LOCKFILE")"
    rm "$LOCKFILE_PID"
    return 1
  fi
  trap "rm $tmpfile ${lockfile}" EXIT
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
  set +e
  ssh "$LOCKHOST" ln "$LOCKFILE_PID" "$LOCKFILE"
  code=$?
  set -e
  if [ $code -ne 0 ]; then
    echoerr "$LOCKFILE locked by $(ssh "$LOCKHOST" cat "$LOCKFILE")"
    ssh "$LOCKHOST" rm "$LOCKFILE_PID"
    return 1
  fi
}

unlockfile_ssh() {
  ssh "$LOCKHOST" rm -f "$LOCKFILE_PID" "$LOCKFILE"
}
