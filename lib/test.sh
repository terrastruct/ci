#!/bin/sh
if [ "${LIB_TEST-}" ]; then
  return 0
fi
LIB_TEST=1
. ./log.sh
. ./job.sh
. ./git.sh

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
  capcode gitdiff "$tmpdir/$1" "$tmpdir/$2"
  if [ $code -eq 0 ]; then
    rm -r "$tmpdir"
  fi
  return $code
}

gitdiff() {
  should_color || true
  _f() {
    # 1. If _COLOR is set we want colors.
    # 2. Use the best diff algorithm.
    # 3. Highlight trailing whitespace.
    gitpure ${_COLOR:+-c color.diff=always} diff \
      --diff-algorithm=histogram \
      --ws-error-highlight=all \
      --no-index "$@"
  }
  # note: Even though we set diff-highlight in the global git config in gitpure,
  # we still have to manually use diff-highlight here as git won't use its pager as
  # we're not sending to a tty.
  if command -v diff-highlight >/dev/null; then
    _f "$@" | diff-highlight | tail -n +3
  else
    _f "$@" | tail -n +3
  fi
}
