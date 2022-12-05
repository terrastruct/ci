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
