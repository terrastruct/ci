#!/bin/sh

if [ "${CI_DEBUG:-}" ]; then
  set -x
fi

# ***
# go related functions
# ***

goos() {
  case $1 in
    macos) _echo darwin ;;
    *) _echo $1 ;;
  esac
}
