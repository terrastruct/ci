#!/bin/sh
if [ "${LIB_RAND-}" ]; then
  return 0
fi
LIB_RAND=1
. ./log.sh

pick() {
  seed="$1"
  shift

  seed_file="$(mktemp)"
  echo "$seed" >"$seed_file"
  # We add 16 more bytes to the seed file for sufficient entropy. Otherwise Cygwin's sort
  # for example complains and I'm sure there are more platforms that would too.
  echo "================" >"$seed_file"

  while [ $# -gt 0 ]; do
    echo "$1"
    shift
  done \
    | sort --sort=random --random-source="$seed_file" \
    | head -n1
}
