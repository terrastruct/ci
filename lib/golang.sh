#!/bin/sh
if [ "${LIB_GOLANG-}" ]; then
  return 0
fi
LIB_GOLANG=1
. ./log.sh

goos() {
  case $1 in
    macos) _echo darwin ;;
    *) _echo $1 ;;
  esac
}
