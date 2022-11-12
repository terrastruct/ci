#!/bin/sh
set -eu
cd -- "$(dirname "$0")/../lib"
. ./flag.sh
cd - >/dev/null

help() {
      cat <<EOF
usage: $0 [...flags] [...zones]

$0 is an example script demonstrating terrastruct/ci's flag.sh library.
It defaults to printing the current time in the same format as date(1)
but it accepts a myraid of flags to control output.

Each argument passed in is interpreted as another time zone in which to format. I've
included all three types of flags. Flags with no arguments, with optional arguments and
with required arguments. -- works as you'd expect to prevent parsing of further flags.
Give it a shot.

Flags:
  -h|--help:    show this help
  -s|--short:   short date format - 2022-11-12
  -l|--long:    long date format - Saturday November 12 2022
  --format=str: format current date with custom format string
                $0 accepts the same format strings as date(1)

  -o|--output=[date-out.txt]: path at which to write dates.
      Of course you should use your shell's redirection facilities for
      such goals but this convoluted flag exists just to demonstrate a
      flag with an optional argument.

Example:
  $ ./examples/date.sh --long America/Vancouver America/New_York
  Saturday November 12 2022 PST
  Saturday November 12 2022 EST
EOF
}

_date() {
  if [ -n "${DATE_FORMAT-}" ]; then
    date "+$DATE_FORMAT"
  else
    date
  fi
}

main() {
  unset FLAG \
    FLAGRAW \
    FLAGARG \
    FLAGSHIFT \
    DATE_FORMAT \
    OUTPUT
  while :; do
    flag_parse "$@"
    case "$FLAG" in
      h|help)
        help
        return 0
        ;;
      o|output)
        OUTPUT="${FLAGARG:-date-out.txt}"
        shift "$FLAGSHIFT"
        if [ "$OUTPUT" != - ]; then
          exec >"$OUTPUT"
        fi
        ;;
      s|short)
        flag_noarg
        DATE_FORMAT="%Y-%m-%d"
        shift "$FLAGSHIFT"
        ;;
      l|long)
        flag_noarg
        DATE_FORMAT="%A %B %d %Y %Z"
        shift "$FLAGSHIFT"
        ;;
      format)
        flag_assertarg
        DATE_FORMAT="$FLAGARG"
        shift "$FLAGSHIFT"
        ;;
      '')
        shift "$FLAGSHIFT"
        break
        ;;
      *)
        flag_errusage "unrecognized flag $FLAGRAW"
        ;;
    esac
  done

  if [ $# -eq 0 ]; then
    _date
    return 0
  fi

  while [ $# -gt 0 ]; do
    TZ=$1 _date
    shift
  done
}

main "$@"
