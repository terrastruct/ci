#!/bin/sh

if [ "${_LIB_PARALLEL:-}" ]; then
  return
fi
_LIB_PARALLEL=1

. "$(dirname "$0")/lib/log.sh"

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
