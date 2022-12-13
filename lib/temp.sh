#!/bin/sh
if [ "${LIB_TEMP-}" ]; then
  return 0
fi
LIB_TEMP=1

ensure_tmpdir() {
  if [ -n "${_TMPDIR-}" ]; then
    return
  fi
  _TMPDIR=$(mktemp -d)
  export _TMPDIR
}

if [ -z "${_TMPDIR-}" ]; then
  trap 'rm -Rf "$_TMPDIR"' EXIT
fi
ensure_tmpdir

temppath() {
  while true; do
    temppath=$_TMPDIR/$(</dev/urandom od -N8 -tx -An -v | tr -d '[:space:]')
    if [ ! -e "$temppath" ]; then
      echo "$temppath"
      return
    fi
  done
}

mktempd() {
  tp=$(temppath)
  mkdir -p "$tp"
  echo "$tp"
}
