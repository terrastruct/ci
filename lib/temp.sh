#!/bin/sh
if [ "${LIB_TEMP-}" ]; then
  return 0
fi
LIB_TEMP=1

ensure_tmpdir() {
  if [ -n "${TMPDIR-}" ]; then
    return
  fi

  TMPDIR=$(mktemp -d)
  trap "rm -r '$TMPDIR'" EXIT
}

mktempd() {
  ensure_tmpdir
  tmpd=$(mktemp -d "$@")
  mv "$tmpd" "$TMPDIR/$(basename $tmpd)"
}

mktempf() {
  ensure_tmpdir
  tmpf=$(mktemp "$@")
  mv "$tmpf" "$TMPDIR/$(basename $tmpf)"
}
