#!/bin/sh
if [ "${LIB_RAND-}" ]; then
  return 0
fi
LIB_RAND=1
. ./log.sh

rand() {
  seed="$1"
  range="$2"

  seed_file="$(mktemp)"
  _echo "$seed" | md5sum > "$seed_file"
  shuf -i "$range" -n 1 --random-source="$seed_file"
}

pick() {
  seed="$1"
  shift
  i="$(rand "$seed" "1-$#")"
  eval "_echo \"\$$i\""
}
