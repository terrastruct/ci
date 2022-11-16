#!/bin/sh
set -eu
cd -- "$(dirname "$0")"
. ./test.sh
. ./flag.sh
cd - >/dev/null

assert_term() {
  args_str="$1"
  shift

  ! flag_parse "$@"
  shift "$FLAGSHIFT"
  assert @ "$*" "$args_str"
}

case_term() {
  set -- 
  assert_term '' "$@"

  set -- --
  assert_term '' "$@"

  set -- --run x - --someflag
  flag_parse "$@"
  assert FLAG run
  flag_reqarg && shift "$FLAGSHIFT"
  assert FLAGARG x
  assert_term '- --someflag' "$@"

  set -- --run x -- --someflag
  flag_parse "$@"
  assert FLAG run
  flag_reqarg && shift "$FLAGSHIFT"
  assert FLAGARG x
  assert_term '--someflag' "$@"

  set -- --run x arg --someflag
  flag_parse "$@"
  assert FLAG run
  flag_reqarg && shift "$FLAGSHIFT"
  assert FLAGARG x
  assert_term 'arg --someflag' "$@"
}

case_equal_sign() {
  set -- -o=meow --o=meow -ok=meow --ok=meow --ok=

  flag_parse "$@"
  assert FLAG o
  flag_reqarg && shift "$FLAGSHIFT"
  assert FLAGARG meow

  flag_parse "$@"
  assert FLAG o
  flag_reqarg && shift "$FLAGSHIFT"
  assert FLAGARG meow

  flag_parse "$@"
  assert FLAG ok
  flag_reqarg && shift "$FLAGSHIFT"
  assert FLAGARG meow

  flag_parse "$@"
  assert FLAG ok
  flag_reqarg && shift "$FLAGSHIFT"
  assert FLAGARG meow

  flag_parse "$@"
  assert FLAG ok
  flag_reqarg && shift "$FLAGSHIFT"
  assert FLAGARG ''

  assert_term '' "$@"
}

case_notequal_sign() {
  case_with_args() {
    set -- -o meow --o meow -ok meow --ok meow --ok ''

    flag_parse "$@"
    assert FLAG o
    flag_reqarg && shift "$FLAGSHIFT"
    assert FLAGARG meow

    flag_parse "$@"
    assert FLAG o
    flag_reqarg && shift "$FLAGSHIFT"
    assert FLAGARG meow

    flag_parse "$@"
    assert FLAG ok
    flag_reqarg && shift "$FLAGSHIFT"
    assert FLAGARG meow

    flag_parse "$@"
    assert FLAG ok
    flag_reqarg && shift "$FLAGSHIFT"
    assert FLAGARG meow

    flag_parse "$@"
    assert FLAG ok
    flag_reqarg && shift "$FLAGSHIFT"
    assert FLAGARG ''

    assert_term '' "$@"
  }

  case_without_args() {
    set -- -o --o -ok --ok

    flag_parse "$@"
    assert FLAG o
    shift "$FLAGSHIFT"
    assert_unset FLAGARG

    flag_parse "$@"
    assert FLAG o
    shift "$FLAGSHIFT"
    assert_unset FLAGARG

    flag_parse "$@"
    assert FLAG ok
    shift "$FLAGSHIFT"
    assert_unset FLAGARG

    flag_parse "$@"
    assert FLAG ok
    shift "$FLAGSHIFT"
    assert_unset FLAGARG

    assert_term '' "$@"
  }

  case_term() {
    set -- --out - -x --flag --

    flag_parse "$@"
    assert FLAG out
    flag_reqarg && shift "$FLAGSHIFT"
    assert FLAGARG -

    flag_parse "$@"
    assert FLAG x
    shift "$FLAGSHIFT"
    assert_unset FLAGARG

    flag_parse "$@"
    assert FLAG flag
    shift "$FLAGSHIFT"
    assert_unset FLAGARG

    assert_term '' "$@"
  }

  runjob case_with_args &
  runjob case_without_args &
  runjob case_term &
  waitjobs
}

case_reqarg() {
  set -- -m
  flag_parse "$@"
  assert FLAG m
  assert flag_reqarg "$(COLOR=0 flag_reqarg 2>&1)" "err: flag -m requires an argument
err: Run with --help for usage."

  set -- --meow
  flag_parse "$@"
  assert FLAG meow
  assert flag_reqarg "$(COLOR=0 flag_reqarg 2>&1)" "err: flag --meow requires an argument
err: Run with --help for usage."

  set -- --jingle=''
  flag_parse "$@"
  assert FLAG jingle
  flag_reqarg && shift "$FLAGSHIFT"
  assert FLAGARG ''
  assert_term '' "$@"
}

case_nonemptyarg() {
  set -- -m
  flag_parse "$@"
  assert FLAG m
  assert flag_nonemptyarg "$(COLOR=0 flag_nonemptyarg 2>&1)" "err: flag -m requires an argument
err: Run with --help for usage."

  set -- --meow
  flag_parse "$@"
  assert FLAG meow
  assert flag_nonemptyarg "$(COLOR=0 flag_nonemptyarg 2>&1)" "err: flag --meow requires an argument
err: Run with --help for usage."

  set -- --jingle=''
  flag_parse "$@"
  assert FLAG jingle
  assert flag_nonemptyarg "$(COLOR=0 flag_nonemptyarg 2>&1)" "err: flag --jingle requires a non-empty argument
err: Run with --help for usage."
}

case_noarg() {
  set -- -z -
  flag_parse "$@"
  assert FLAG z
  flag_noarg && shift "$FLAGSHIFT"
  assert_unset FLAGARG
  assert_term '-' "$@"

  set -- -z ok
  flag_parse "$@"
  assert FLAG z
  flag_noarg && shift "$FLAGSHIFT"
  assert_unset FLAGARG
  assert_term 'ok' "$@"

  set -- -z=ok
  flag_parse "$@"
  assert FLAG z
  assert flag_noarg "$(COLOR=0 flag_noarg 2>&1)" "err: flag -z does not accept an argument
err: Run with --help for usage."
}

case_flag_fmt() {
  set -- -s --s -s= -long --long --long=

  flag_parse "$@"
  assert FLAGRAW -s
  shift "$FLAGSHIFT"

  flag_parse "$@"
  assert FLAGRAW -s
  shift "$FLAGSHIFT"

  flag_parse "$@"
  assert FLAGRAW -s
  shift "$FLAGSHIFT"

  flag_parse "$@"
  assert FLAGRAW --long
  shift "$FLAGSHIFT"

  flag_parse "$@"
  assert FLAGRAW --long
  shift "$FLAGSHIFT"

  flag_parse "$@"
  assert FLAGRAW --long
  shift "$FLAGSHIFT"

  assert_term '' "$@"
}

job_parseflags "$@"
runjob case_term &
runjob case_equal_sign &
runjob case_notequal_sign &
runjob case_reqarg &
runjob case_nonemptyarg &
runjob case_noarg &
runjob case_flag_fmt &
waitjobs
