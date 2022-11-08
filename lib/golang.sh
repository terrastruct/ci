#!/bin/sh

if [ "${_LIB_GOLANG:-}" ]; then
  return
fi
_LIB_GOLANG=1

. "$(dirname "$0")/lib/log.sh"

goos() {
  case $1 in
    macos) _echo darwin ;;
    *) _echo $1 ;;
  esac
}
