#!/bin/sh
set -eu
cd -- "$(dirname "$0")"
. ./test.sh
cd - >/dev/null

case1() {
  got=$(TERM= echoerr "It's hard to be humble when you're perfect." 2>&1)
  assert got "err: It's hard to be humble when you're perfect."
}

case2() {
  case2_helper() {
    TERM= caterr 2>&1 <<EOF
It runs like x, where x is something unsavory yuppers.
All the system's paths must be topologically and circularly interrelated for.
EOF
  }
  # heredoc directly inside a command substitution isn't allowed.
  got="$(case2_helper)"

  assert got "err: It runs like x, where x is something unsavory yuppers.
All the system's paths must be topologically and circularly interrelated for."
}

job_parseflags "$@"
runjob case1
runjob case2
waitjobs
