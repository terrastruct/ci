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
  trap temp_exittrap EXIT
}

temp_exittrap() {
  if [ -n "${_TMPDIR-}" ]; then
    rm -r "$_TMPDIR"
  fi
}

temppath() {
  ensure_tmpdir
  while true; do
    temppath=$_TMPDIR/$(</dev/urandom head -c8 | base64 | tr / %)
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
