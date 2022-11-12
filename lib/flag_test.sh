#!/bin/sh
set -eu
cd -- "$(dirname "$0")"
. ./flag.sh
. ./test.sh
cd - >/dev/null

case1() {
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

case2() {
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

case3() {
  set -- -m -- - wow lol more args

  flag_parse "$@"
  assert FLAG m
  assert FLAGARG ''
  shift "$FLAGSHIFT"

  assert @ "$*" '-- - wow lol more args'
}

case4() {
  set -- -some -

  flag_parse "$@"
  assert FLAG some
  assert FLAGARG -
  shift "$FLAGSHIFT"

  assert @ "$*" ''
}

case5() {
  FLAGRAW=-m
  assert flag_reqarg "$(TERM= flag_reqarg 2>&1)" "err: flag -m requires an argument
     Run with --help for usage."

  FLAGRAW=--meow
  assert flag_reqarg "$(TERM= flag_reqarg 2>&1)" "err: flag --meow requires an argument
     Run with --help for usage."
}

case6() {
  set -- -o --long

  flag_parse "$@"
  assert FLAG o
  assert FLAGARG ''
  shift "$FLAGSHIFT"

  assert @ "$*" '--long'
}

job_parseflags "$@"
runjob case1
runjob case2
runjob case3
runjob case4
runjob case5
runjob case6
waitjobs
