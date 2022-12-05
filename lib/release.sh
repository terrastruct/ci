#!/bin/sh
if [ "${LIB_RELEASE-}" ]; then
  return 0
fi
LIB_RELEASE=1
. ./log.sh

ensure_goos() {
  if [ -n "${GOOS-}" ]; then
    return
  fi
  ensure_os
  case "$OS" in
    macos) export GOOS=darwin;;
    *) export GOOS=$1;;
  esac
}

ensure_os() {
  if [ -n "${OS-}" ]; then
    return
  fi
  uname=$(uname)
  case $uname in
    Linux) OS=linux;;
    Darwin) OS=macos;;
    FreeBSD) OS=freebsd;;
    CYGWIN_NT*|MINGW32_NT*) OS=windows;;
    *) OS=$uname;;
  esac
}

ensure_arch() {
  if [ -n "${ARCH-}" ]; then
    return
  fi
  uname_m=$(uname -m)
  case $uname_m in
    aarch64) ARCH=arm64;;
    x86_64) ARCH=amd64;;
    *) ARCH=$uname_m;;
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
  # If it can be created, we can use it.
  sh_c "mkdir -p '$1' 2>/dev/null"
}

ensure_prefix() {
  ensure_os
  ensure_arch
  if [ -z "${PREFIX-}" -a "$OS" = macos -a "$ARCH" = arm64 ]; then
    # M1 Mac's do not allow modifications to /usr/local even with sudo.
    PREFIX=$HOME/.local
  fi
  PREFIX=${PREFIX:-/usr/local}

  sh_c="sh_c"
  # The reason for checking whether bin is writable is that on macOS you have /usr/local
  # owned by root but you don't need root to write to its subdirectories which is all we
  # need to do.
  if ! is_writable_dir "$PREFIX/bin"; then
    sh_c="sudo_sh_c"
  fi
}
