#!/bin/sh
set -eu
cd -- "$(dirname "$0")"
. ./test.sh
. ./log.sh
cd - >/dev/null

case1() {
  got=$(COLOR=0 echoerr "It's hard to be humble when you're perfect." 2>&1)
  assert got "err: It's hard to be humble when you're perfect."
}

case2() {
  case2_got() {
    COLOR=0 caterr 2>&1 <<EOF
It runs like x, where x is something unsavory yuppers.
All the system's paths must be topologically and circularly interrelated for.
EOF
  }
  case2_exp() {
    cat <<EOF
err: It runs like x, where x is something unsavory yuppers.
err: All the system's paths must be topologically and circularly interrelated for.
EOF
  }
  # heredoc directly inside a command substitution isn't allowed.
  got="$(case2_got)"
  exp="$(case2_exp)"

  assert got "$exp"
}

case3() {
  got=$(COLOR=0 header "installing d2 version-x" 2>&1)
  assert got "/* installing d2 version-x */"

  got=$(COLOR=0 bigheader "installing d2 version-x" 2>&1)
  assert got "/****************************************************************
 * installing d2 version-x
 ****************************************************************/"

  got=$(COLOR=0 bigheader "one
two" 2>&1)
  assert got "/****************************************************************
 * one
 * two
 ****************************************************************/"
}

job_parseflags "$@"
runjob case1 &
runjob case2 &
runjob case3 &
waitjobs
