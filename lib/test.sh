#!/bin/sh
if [ "${LIB_TEST-}" ]; then
  return 0
fi
LIB_TEST=1
. ./log.sh
. ./job.sh
. ./git.sh
. ./temp.sh

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
    testdiff_vars exp got
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

testdiff_vars() {(
  _TMPDIR= && ensure_tmpdir
  tmpdir=$(mktempd)/testdiff_vars
  mkdir -p "$tmpdir"
  eval "_echo \"\$$1\"" > "$tmpdir/$1"
  eval "_echo \"\$$2\"" > "$tmpdir/$2"
  capcode testdiff "$tmpdir/$1" "$tmpdir/$2"
  if [ "$code" -eq 0 ]; then
    rm -Rf "$_TMPDIR"
  fi
  return "$code"
)}

testdiff() {
  if diff "$@" >/dev/null; then
    return 0
  fi

  should_color || true
  _f() {
    # 1. If _COLOR is set we want colors.
    # 2. Use the best diff algorithm.
    # 3. Highlight trailing whitespace.
    git_pure diff \
      --diff-algorithm=histogram \
      --ws-error-highlight=all \
      --no-index "$@"
  }
  # note: Even though we set diff-highlight in the global git config in git_pure,
  # we still have to manually use diff-highlight here as git won't use its pager as
  # we're not sending to a tty.
  if command -v diff-highlight >/dev/null; then
    _f "$@" | diff-highlight | tail -n +3
  else
    _f "$@" | tail -n +3
  fi
  return 1
}
