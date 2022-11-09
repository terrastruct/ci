#!/bin/sh

if [ "${_LIB_PARALLEL:-}" ]; then
  return
fi
_LIB_PARALLEL=1

. "$(dirname "$0")/log.sh"

wait_jobs() {
  JOBS="$(jobs -l)"
  for pid in $(jobs -p); do
    if ! wait "$pid"; then
      echoerr <<EOF
waiting on $pid failed:
  $(job_info "$pid")
EOF
      FAILURE=1
    fi
  done
  if [ -n "${FAILURE-}" ]; then
    exit 1
  fi
}

job_info() {
  _echo "$JOBS" | grep "$1"
}
