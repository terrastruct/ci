#!/bin/sh
if [ "${LIB_FLAG-}" ]; then
  return 0
fi
LIB_FLAG=1
. ./log.sh

# Always shift with FLAGSHIFT even if FLAG='' indicating no more flags.
parseflag() {
  case "${1-}" in
    -*=*)
      # Remove everything after first equal sign.
      FLAG="${1%%=*}"
      # Remove leading hyphens.
      FLAG="${FLAG#-}"; FLAG="${FLAG#-}"
      # Remove everything before first equal sign.
      FLAGARG="${1#*=}"
      FLAGSHIFT=1
      return 0
      ;;
    -)
      FLAG=
      FLAGARG=
      FLAGSHIFT=0
      return 0
      ;;
    --)
      FLAG=
      FLAGARG=
      FLAGSHIFT=1
      return 0
      ;;
    -*)
      # Remove leading hyphens.
      FLAG="${1#-}"; FLAG="${FLAG#-}"
      FLAGARG=
      FLAGSHIFT=1
      if [ $# -gt 1 ]; then
        FLAGSHIFT=2
        if [ "$2" = -- ] ; then
          FLAGARG=
        else
          FLAGARG="$2"
        fi
      fi
      return 0
      ;;
    *)
      FLAG=
      FLAGARG=
      FLAGSHIFT=0
      return 0
      ;;
  esac
}

flag_req_arg_err() {
  echoerr "flag $(_flag_fmt) requires an argument, run with --help to see full usage"
  exit 1
}

_flag_fmt() {
  if [ "$(printf %s "$FLAG" | wc -c)" -eq 1 ]; then
    _echo "-$FLAG"
  else
    _echo "--$FLAG"
  fi
}
