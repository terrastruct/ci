#!/bin/sh
set -eu
cd -- "$(dirname "$0")"
. ./test.sh
. ./make.sh
cd - >/dev/null

git() {
  git_pure "$@"
}

case1() {
  tmpdir=$(mktempd)
  cd "$tmpdir"
  git init
  cat <<EOF >Makefile
true:
	true
EOF

  if ! _make; then
    echoerr "expected _make to succeed"
    return 1
  fi
  cat <<EOF >Makefile
false:
	false
EOF
  if _make; then
    echoerr "expected _make to fail"
    return 1
  fi
}

case2() {
  libd=$(cd "$(dirname "$0")" && pwd)

  tmpdir=$(mktempd)
  cd "$tmpdir"
  git init
  cp "$libd/../LICENSE" .
  git add -A
  git commit -m 'Add License'

  cat <<EOF >Makefile
true:
	true
EOF

  if ! _make; then
    echoerr "expected _make to succeed"
    return 1
  fi
  cat <<EOF >Makefile
false:
	false
EOF
  if _make; then
    echoerr "expected _make to fail"
    return 1
  fi
}

job_parseflags "$@"
runjob case1 &
runjob case2 &
waitjobs
