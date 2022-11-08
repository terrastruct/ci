#!/bin/sh

if [ "${_LIB_GOLANG:-}" ]; then
  return
fi
_LIB_GOLANG=1

goos() {
  case $1 in
    macos) _echo darwin ;;
    *) _echo $1 ;;
  esac
}
