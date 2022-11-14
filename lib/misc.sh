#!/bin/sh
if [ "${LIB_MISC-}" ]; then
  return 0
fi
LIB_MISC=1
. ./log.sh

goos() {
  case $1 in
    macos) _echo darwin ;;
    *) _echo $1 ;;
  esac
}

os() {
  uname="$(uname)"
  case $uname in
    Linux) echo linux ;;
    Darwin) echo macos ;;
    FreeBSD) echo freebsd ;;
    *) echo "$uname" ;;
  esac
}

arch() {
  uname_m=$(uname -m)
  case $uname_m in
    aarch64) echo arm64 ;;
    x86_64) echo amd64 ;;
    *) echo "$uname_m" ;;
  esac
}

aws() {
  # Without the redirection aws's cli will write directly to /dev/tty bypassing prefix.
  command aws "$@" > /dev/stdout
}

docker_run() {
  sh_c docker run -it --rm \
    -v "$HOME:$HOME" \
    -w "$HOME" \
    -e HOME \
    -u "$(id -u):$(id -g)" \
    "$@"
}
