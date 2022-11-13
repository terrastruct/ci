#!/bin/sh
if [ "${LIB_MISC-}" ]; then
  return 0
fi
LIB_MISC=1
. ./log.sh

goos() {
  case $1 in
    macos) _echo darwin ;;
    *) _echo $1 ;;
  esac
}
