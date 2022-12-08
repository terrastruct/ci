#!/bin/sh
if [ "${LIB_TEMP-}" ]; then
  return 0
fi
LIB_TEMP=1

if [ -z "${_TMPDIR-}" ]; then
  _TMPDIR=$(mktemp -d)
  export _TMPDIR
  trap 'rm -Rf "$_TMPDIR"' EXIT
fi

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
