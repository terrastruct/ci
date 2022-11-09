#!/bin/sh

if [ "${_LIB_TEST:-}" ]; then
  return 0
fi
_LIB_TEST=1

assert() {
  if [ $# -gt 2 ]; then
    _ASSERT_EXP="$3"
    _ASSERT_GOT="$2"
  else
    eval "_ASSERT_GOT=\$$1"
    _ASSERT_EXP="$2"
  fi
  if [ "$_ASSERT_GOT" != "$_ASSERT_EXP" ]; then
    printferr "expected $1='%s' but got '%s'\n" "$_ASSERT_EXP" "$_ASSERT_GOT"
    exit 1
  fi
}
