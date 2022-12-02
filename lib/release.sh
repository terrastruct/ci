#!/bin/sh
if [ "${LIB_RELEASE-}" ]; then
  return 0
fi
LIB_RELEASE=1
. ./log.sh

goos() {
  case $1 in
    macos) echo darwin;;
    *) echo $1;;
  esac
}

os() {
  uname=$(uname)
  case $uname in
    Linux) echo linux;;
    Darwin) echo macos;;
    FreeBSD) echo freebsd;;
    CYGWIN_NT*) echo windows;;
    *) echo "$uname";;
  esac
}

arch() {
  uname_m=$(uname -m)
  case $uname_m in
    aarch64) echo arm64;;
    x86_64) echo amd64;;
    *) echo "$uname_m";;
  esac
}

gh_repo() {
  gh repo view --json nameWithOwner --template '{{ .nameWithOwner }}'
}

manpath() {
  if command -v manpath >/dev/null; then
    command manpath
  elif man -w 2>/dev/null; then
    man -w
  else
    echo "${MANPATH-}"
  fi
}

is_writable_dir() {
  # The path has to exist for -w to succeed.
  sh_c "mkdir -p '$1' 2>/dev/null" || true
  if [ ! -w "$1" ]; then
    return 1
  fi
}
