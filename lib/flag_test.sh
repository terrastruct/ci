#!/bin/sh
set -eu

. "$(dirname "$0")/flag.sh"
. "$(dirname "$0")/test.sh"
. "$(dirname "$0")/parallel.sh"

case_one() {
  set -- -ok=meow --ok=meow -

  flag_parse "$@"
  assert FLAG ok
  assert FLAGARG meow
  shift "$FLAGSHIFT"

  flag_parse "$@"
  assert FLAG ok
  assert FLAGARG meow
  shift "$FLAGSHIFT"

  flag_parse "$@"
  assert FLAG ''
  assert FLAGARG ''
  shift "$FLAGSHIFT"

  assert @ "$*" '-'
}

case_two() {
  set -- -m ok --coola joola --

  flag_parse "$@"
  assert FLAG m
  assert FLAGARG ok
  shift "$FLAGSHIFT"

  flag_parse "$@"
  assert FLAG coola
  assert FLAGARG joola
  shift "$FLAGSHIFT"

  flag_parse "$@"
  assert FLAG ''
  assert FLAGARG ''
  shift "$FLAGSHIFT"

  assert @ "$*" ''
}

case_three() {
  set -- -m -- - wow lol more args

  flag_parse "$@"
  assert FLAG m
  assert FLAGARG ''
  shift "$FLAGSHIFT"

  assert @ "$*" '- wow lol more args'
}

case_four() {
  set -- -some -

  flag_parse "$@"
  assert FLAG some
  assert FLAGARG -
  shift "$FLAGSHIFT"

  assert @ "$*" ''
}

case_five() {
  FLAG=m
  assert flag_req_arg_err "$(TERM= flag_req_arg_err 2>&1)" "err: flag -m requires an argument, run with --help to see full usage"

  FLAG=meow
  assert flag_req_arg_err "$(TERM= flag_req_arg_err 2>&1)" "err: flag --meow requires an argument, run with --help to see full usage"
}

runjob case_one
runjob case_two
runjob case_three
runjob case_four
runjob case_five
waitjobs
