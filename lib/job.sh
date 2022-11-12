#!/bin/sh
if [ "${LIB_JOB-}" ]; then
  return 0
fi
LIB_JOB=1
. ./log.sh
. ./flag.sh

# Unfortunately this leaks subprocesses when killed via a signal. Not sure how to remedy.
# I believe the code is 100% correct. Shell's seem quite buggy in their handling and
# propogating of signals. Not sure how to debug even without something like gdb and going
# through the source code of the shell too.
runjob() {
  job_name="$1"
  shift
  if [ $# -eq 0 ]; then
    set "$job_name"
  fi

  if [ -n "${JOB_FILTER-}" ]; then
    if ! _echo "$job_name" | grep -q "$JOB_FILTER"; then
      # Skipped.
      return 0
    fi
  fi

  COLOR="$(get_rand_color "$job_name")"
  _job_name="$job_name"
  job_name="$(setaf "$COLOR" "$job_name")"
  _echo "$job_name^:" "$*"

  # We need to make sure we exit with a non zero exit if the command fails.
  # /bin/sh does not support -o pipefail unfortunately.
  job_tmpdir="$(mktemp -d)"
  stdout="$job_tmpdir/stdout"
  stderr="$job_tmpdir/stderr"
  mkfifo "$stdout"
  mkfifo "$stderr"

  eval "_runjob $* &"
}

# This runs in a subshell so that we get output from the job even if it's shutting
# down due to a ctrl+c. Without the subshell, sed would be a job of the parent
# shell and so waitjobs would send SIGTERM to it.
_runjob() {(
  # We add the prefix to all lines and remove any warning lines about recursive make.
  # We cannot silence these with -s which is unfortunate.
  sed -e "s#^#$job_name: #" -e "/make\[.\]: warning: -j/d" "$stdout" &
  sed -e "s#^#$job_name: #" -e "/make\[.\]: warning: -j/d" "$stderr" >&2 &

  start="$(awk 'BEGIN{srand(); print srand()}')"
  trap runjob_exittrap EXIT
  "$@" >"$stdout" 2>"$stderr"
)}

runjob_exittrap() {
  code="$?"
  end="$(awk 'BEGIN{srand(); print srand()}')"
  dur="$((end - start))"

  waitjobs
  if [ "$code" -eq 0 ]; then
    _echo "$job_name\$:" "$(setaf 2 success)" "($(echo_dur "$dur"))"
  else
    _echo "$job_name\$:" "$(setaf 1 failure)" "($(echo_dur "$dur"))"
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

job_flag_parses() {
  while :; do
    flag_parse "$@"
    shift "$FLAGSHIFT"

    case "$FLAG" in
      run) JOB_FILTER="$FLAGARG" ;;
      h|help) cat <<EOF
usage: $0 [--run=jobregex]
EOF
exit 0
;;
      "") break ;;
      *)
        echoerr "unrecognized flag $FLAG, run with --help to see usage"
        return 1
        ;;
    esac
  done

  if [ $# -gt 0 ]; then
    echoerr "$0 does not accept any arguments, run with --help to see usage"
    return 1
  fi
}
