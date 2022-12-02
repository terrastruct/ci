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
  _echo "$seed" > "$seed_file"

  for i in $(seq $#); do
    eval "_echo \"\$$i\""
  done | sort --sort=random --random-source="$seed_file" | head -n1
}
