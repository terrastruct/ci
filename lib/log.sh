#!/bin/sh

if [ "${_LIB_LOG:-}" ]; then
  return
fi
_LIB_LOG=1

. "$(dirname "$0")/rand.sh"

_echo() {
  printf '%s\n' "$*"
}

tput() {
  if [ -n "$TERM" ]; then
    command tput "$@"
  fi
}

setaf() {
  tput setaf "$1"
  shift
  printf '%s' "$*"
  tput sgr0
}

echoerr() {
  printf '%s ' "$(setaf 1 err:)" >&2
  if [ "$#" -gt 0 ]; then
    printf '%s\n' "$*" >&2
  else
    cat >&2
  fi
}

sh_c() {
  printf '%s %s\n' "$(setaf 3 exec:)" "$*"
  "$@"
}

get_rand_color() {
  # 1-6 are regular and 9-14 are bright.
  # 1,2 and 9,10 are red and green but we use those for success and failure.
  pick "$*" 3 4 5 6 11 12 13 14
}

hide() {
  out="$(mktemp)"
  set +e
  "$@" >"$out" 2>&1
  code="$?"
  set -e
  if [ "$code" -eq 0 -a -z "${CI_DEBUG:-}" ]; then
    return
  fi
  cat "$out" >&2
  exit "$code"
}

echo_dur() {
  local dur=$1
  local h=$((dur/60/60))
  local m=$((dur/60%60))
  local s=$((dur%60))
  printf '%dh%dm%ds' "$h" "$m" "$s"
}

sponge() {
  dst="$1"
  tmp="$(mktemp)"
  cat > "$tmp"
  cat "$tmp" > "$dst"
}

stripansi() {
  # First regex gets rid of standard xterm escape sequences for controlling
  # visual attributes.
  # The second regex I'm not 100% sure, the reference says it selects the US
  # encoding but I'm not sure why that's necessary or why it always occurs
  # in tput sgr0 before the standard escape sequence.
  # See tput sgr0 | xxd
  sed -e $'s/\x1b\[[0-9;]*m//g' -e $'s/\x1b(.//g'
}

runtty() {
  case "$(uname)" in
    Darwin)
      script -q /dev/null "$@"
      ;;
    Linux)
      script -eqc "$*"
      ;;
    *)
      echoerr "runtty: unsupported OS $(uname)"
  esac
}

runp() {(
  prefix="$1"
  shift

  COLOR="$(get_rand_color "$prefix")"
  prefix="$(setaf "$COLOR" "$prefix")"
  _echo "$prefix^:" "$*"

  # We need to make sure we exit with a non zero exit if the command fails.
  # /bin/sh does not support -o pipefail unfortunately.
  fifo="$(mktemp -d)/fifo"
  mkfifo "$fifo"
  # We add the prefix to all lines and remove any warning lines about recursive make.
  # We cannot silence these with -s which is unfortunate.
  sed -e "s#^#$prefix: #" -e "/make\[.\]: warning: -j/d" "$fifo" &

  exit_trap() {
    code="$?"
    end="$(awk 'BEGIN{srand(); print srand()}')"
    dur="$((end - start))"

    if [ "$code" -eq 0 ]; then
      _echo "$prefix\$:" "$(setaf 2 success)" "($(echo_dur $dur))"
    else
      _echo "$prefix\$:" "$(setaf 1 failure)" "($(echo_dur $dur))"
    fi
  }
  trap exit_trap EXIT

  start="$(awk 'BEGIN{srand(); print srand()}')"
  "$@" >"$fifo" 2>&1
)}
