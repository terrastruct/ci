#!/bin/sh
if [ "${LIB_RELEASE-}" ]; then
  return 0
fi
LIB_RELEASE=1
. ./log.sh

ensure_os() {
  if [ -n "${OS-}" ]; then
    # Windows defines OS=Windows_NT.
    if [ "$OS" = Windows_NT ]; then
      OS=windows
    fi
    return
  fi
  uname=$(uname)
  case $uname in
    Linux) OS=linux;;
    Darwin) OS=macos;;
    FreeBSD) OS=freebsd;;
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

ensure_goos() {
  if [ -n "${GOOS-}" ]; then
    return
  fi
  ensure_os
  case "$OS" in
    macos) export GOOS=darwin;;
    *) export GOOS=$OS;;
  esac
}

ensure_goarch() {
  if [ -n "${GOARCH-}" ]; then
    return
  fi
  ensure_arch
  case "$ARCH" in
    *) export GOARCH=$ARCH;;
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
  mkdir -p "$1" 2>/dev/null
  # directory must exist otherwise -w returns 1 even for paths that should be writable.
  [ -w "$1" ]
}

ensure_prefix() {
  if [ -n "${PREFIX-}" ]; then
    return
  fi
  # The reason for checking whether lib is writable is that on macOS you have /usr/local
  # owned by root but you don't need root to write to its subdirectories which is all we
  # need to do.
  if ! is_writable_dir "/usr/local/lib"; then
    # This also handles M1 Mac's which do not allow modifications to /usr/local even
    # with sudo.
    PREFIX=$HOME/.local
  else
    PREFIX=/usr/local
  fi
}

ensure_prefix_sh_c() {
  ensure_prefix

  sh_c="sh_c"
  # The reason for checking whether lib is writable is that on macOS you have /usr/local
  # owned by root but you don't need root to write to its subdirectories which is all we
  # need to do.
  if ! is_writable_dir "$PREFIX/lib"; then
    sh_c="sudo_sh_c"
  fi
}
