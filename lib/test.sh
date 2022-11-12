#!/bin/sh
if [ "${LIB_TEST-}" ]; then
  return 0
fi
LIB_TEST=1
. ./log.sh
. ./job.sh

assert() {
  if [ $# -gt 2 ]; then
    exp="$3"
    got="$2"
  else
    eval "got=\$$1"
    exp="$2"
  fi
  if [ "$got" != "$exp" ]; then
    echoerr "unexpected $1"
    gitdiff_vars exp got
    return 1
  fi
}

gitdiff_vars() {
  tmpdir="$(mktemp -d)"
  eval "_echo \"\$$1\"" > "$tmpdir/$1"
  eval "_echo \"\$$2\"" > "$tmpdir/$2"
  set +e
  gitdiff "$tmpdir/$1" "$tmpdir/$2"
  code="$?"
  set -e
  if [ $code -eq 0 ]; then
    rm -r "$tmpdir"
  fi
  return $code
}

gitdiff() {(
  mkfifo "$tmpdir/fifo"
  cat "$tmpdir/fifo" | diff-highlight | tail -n +3 &
  trap waitjobs EXIT
  # 1. If TERM is set we want colors regardless of if output is a TTY.
  # 2. Use the best diff algorithm.
  # 3. Highlight trailing whitespace.
  GIT_CONFIG_NOSYSTEM=1 HOME= git ${TERM:+-c color.diff=always} diff \
    --diff-algorithm=histogram \
    --ws-error-highlight=all \
    --no-index "$@" >"$tmpdir/fifo"
)}
