#!/bin/sh

if [ "${_LIB_FLAG:-}" ]; then
  return 0
fi
_LIB_FLAG=1

. "$(dirname "$0")/log.sh"

# Always use FLAGSHIFT even if FLAG=''
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
      if [ "${2-}" = -- ] ; then
        FLAGARG=
      else
        FLAGARG="${2-}"
      fi
      FLAGSHIFT=2
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
