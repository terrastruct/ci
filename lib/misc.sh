#!/bin/sh
if [ "${LIB_MISC-}" ]; then
  return 0
fi
LIB_MISC=1
. ./log.sh

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
    -e _COLOR \
    -u "$(id -u):$(id -g)" \
    "$@"
}
