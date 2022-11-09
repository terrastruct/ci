#!/bin/sh

if [ "${_LIB_PARALLEL:-}" ]; then
  return
fi
_LIB_PARALLEL=1

. "$(dirname "$0")/log.sh"

runjob() {
  prefix="$1"
  if [ $# -gt 1 ]; then
    shift
  fi

  if [ -n "${JOB_FILTER-}" ]; then
    if ! _echo "$prefix" | grep -q "$JOB_FILTER"; then
      # Skipped.
      return 0
    fi
  fi

  COLOR="$(get_rand_color "$prefix")"
  prefix="$(setaf "$COLOR" "$prefix")"
  _echo "$prefix^:" "$*"

  # We need to make sure we exit with a non zero exit if the command fails.
  # /bin/sh does not support -o pipefail unfortunately.
  stdout="$(mktemp -d)/stdout"
  stderr="$(mktemp -d)/stderr"
  mkfifo "$stdout"
  mkfifo "$stderr"

  (
    # We add the prefix to all lines and remove any warning lines about recursive make.
    # We cannot silence these with -s which is unfortunate.
    sed -e "s#^#$prefix: #" -e "/make\[.\]: warning: -j/d" "$stdout" &
    sed -e "s#^#$prefix: #" -e "/make\[.\]: warning: -j/d" "$stderr" >&2 &

    trap runjob_exittrap EXIT
    start="$(awk 'BEGIN{srand(); print srand()}')"
    # This runs in a subshell to avoid clobbering stdout and stderr in the exit trap.
    ( "$@" >"$stdout" 2>"$stderr" )
  ) &

  if [ -n "${MAKE_LOG:-}" ]; then
    waitjobs
  fi
}

runjob_exittrap() {
  code="$?"
  end="$(awk 'BEGIN{srand(); print srand()}')"
  dur="$((end - start))"

  if [ "$code" -eq 0 ]; then
    _echo "$prefix\$:" "$(setaf 2 success)" "($(echo_dur "$dur"))"
  else
    _echo "$prefix\$:" "$(setaf 1 failure)" "($(echo_dur "$dur"))"
  fi
}

waitjobs() {
  JOBS="$(jobs -l)"
  trap waitjobs_sigtrap SIGINT SIGTERM

  for pid in $(jobs -p); do
    if ! wait "$pid"; then
      echoerr <<EOF
waiting on $pid failed:
  $(jobinfo "$pid")
EOF
      FAILURE=1
    fi
  done
  if [ -n "${FAILURE-}" ]; then
    exit 1
  fi
}

jobinfo() {
  _echo "$JOBS" | grep "$1"
}

waitjobs_sigtrap() {
  for pid in $(jobs -p); do
    kill "$pid" 2> /dev/null || true
  done
  waitjobs
}
