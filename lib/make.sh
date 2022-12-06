#!/bin/sh
if [ "${LIB_MAKE-}" ]; then
  return 0
fi
LIB_MAKE=1
. ./log.sh
. ./git.sh
. ./ci.sh

_make() {
  if [ -n "${CI-}" ] && ! is_changed .; then
    return
  fi
  if [ -z "${CI_MAKE_ROOT-}" ]; then
    CI_MAKE_ROOT=1
  else
    CI_MAKE_ROOT=0
  fi

  ensure_git_base
  capcode make -sj8 "$@"
  if [ "$code" != 0 ]; then
    notify "$code"
    return "$code"
  fi
  ci_waitjobs
}
