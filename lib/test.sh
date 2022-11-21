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

assert_unset() {
  if [ "$(eval "_echo \"\${$1+x}\"")" = x ]; then
    eval "got=\$$1"
    echoerr "expected unset $1 but got: $got"
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
  if command -v diff-highlight >/dev/null; then
    # https://github.com/git/git/blob/master/contrib/diff-highlight/README
    cat "$tmpdir/fifo" | diff-highlight | tail -n +3 &
  else
    cat "$tmpdir/fifo" | tail -n +3 &
  fi
  trap waitjobs EXIT
  should_color || true
  # 1. If _COLOR is set we want colors.
  # 2. Use the best diff algorithm.
  # 3. Highlight trailing whitespace.
  GIT_CONFIG_NOSYSTEM=1 HOME= git ${_COLOR:+-c color.diff=always} diff \
    --diff-algorithm=histogram \
    --ws-error-highlight=all \
    --no-index "$@" >"$tmpdir/fifo"
)}
