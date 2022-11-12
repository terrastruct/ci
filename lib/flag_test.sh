#!/bin/sh
set -eu
cd -- "$(dirname "$0")"
. ./flag.sh
. ./test.sh
cd - >/dev/null

case1() {
  set -- -ok=meow --ok=meow -

  parseflag "$@"
  assert FLAG ok
  assert FLAGARG meow
  shift "$FLAGSHIFT"

  parseflag "$@"
  assert FLAG ok
  assert FLAGARG meow
  shift "$FLAGSHIFT"

  parseflag "$@"
  assert FLAG ''
  assert FLAGARG ''
  shift "$FLAGSHIFT"

  assert @ "$*" '-'
}

case2() {
  set -- -m ok --coola joola --

  parseflag "$@"
  assert FLAG m
  assert FLAGARG ok
  shift "$FLAGSHIFT"

  parseflag "$@"
  assert FLAG coola
  assert FLAGARG joola
  shift "$FLAGSHIFT"

  parseflag "$@"
  assert FLAG ''
  assert FLAGARG ''
  shift "$FLAGSHIFT"

  assert @ "$*" ''
}

case3() {
  set -- -m -- - wow lol more args

  parseflag "$@"
  assert FLAG m
  assert FLAGARG ''
  shift "$FLAGSHIFT"

  assert @ "$*" '- wow lol more args'
}

case4() {
  set -- -some -

  parseflag "$@"
  assert FLAG some
  assert FLAGARG -
  shift "$FLAGSHIFT"

  assert @ "$*" ''
}

case5() {
  FLAG=m
  assert flag_req_arg_err "$(TERM= flag_req_arg_err 2>&1)" "err: flag -m requires an argument, run with --help to see full usage"

  FLAG=meow
  assert flag_req_arg_err "$(TERM= flag_req_arg_err 2>&1)" "err: flag --meow requires an argument, run with --help to see full usage"
}

job_parseflags "$@"
runjob case1
runjob case2
runjob case3
runjob case4
runjob case5
waitjobs
