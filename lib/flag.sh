#!/bin/sh
if [ "${LIB_FLAG-}" ]; then
  return 0
fi
LIB_FLAG=1
. ./log.sh

# flag_parse implements a robust flag parser.
#
# For a full fledge example see ../examples/date.sh
#
# notes:
# - Always shift with FLAGSHIFT even if FLAG='' indicates no more flags.
# - If the flag has no argument, remember to add back FLAGARG into $@
#   and shift one less than FLAGSHIFT.
# - If a flag always requires an argument, use flag_assert_arg.
# - If a flag does not require an argument, use flag_no_arg.
flag_parse() {
  case "${1-}" in
    -*=*)
      # Remove everything after first equal sign.
      FLAG="${1%%=*}"
      # Remove leading hyphens.
      FLAG="${FLAG#-}"; FLAG="${FLAG#-}"
      # Remove everything before first equal sign.
      FLAGARG="${1#*=}"
      FLAGSHIFT=1
      ;;
    -)
      FLAG=
      FLAGARG=
      FLAGSHIFT=0
      ;;
    --)
      FLAG=
      FLAGARG=
      FLAGSHIFT=1
      ;;
    -*)
      # Remove leading hyphens.
      FLAG="${1#-}"; FLAG="${FLAG#-}"
      FLAGARG=
      FLAGSHIFT=1
      if [ $# -gt 1 ]; then
        case "$2" in
          -)
            FLAGARG="$2"
            FLAGSHIFT=2
            ;;
          -*)
            ;;
          *)
            FLAGARG="$2"
            FLAGSHIFT=2
            ;;
        esac
      fi
      ;;
    *)
      FLAG=
      FLAGARG=
      FLAGSHIFT=0
      ;;
  esac
  return 0
}

flag_assert_arg() {
  if [ -z "$FLAGARG" ]; then
    echoerr "flag $(_flag_fmt) requires an argument, run with --help to see full usage"
    return 1
  fi
}

flag_no_arg() {
  if [ "$FLAGSHIFT" -eq 2 ]; then
    FLAGSHIFT=1
  fi
}

_flag_fmt() {
  if [ "$(printf %s "$FLAG" | wc -c)" -eq 1 ]; then
    _echo "-$FLAG"
  else
    _echo "--$FLAG"
  fi
}
