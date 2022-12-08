#!/bin/sh
if [ "${LIB_GITHUB-}" ]; then
  return 0
fi
LIB_GITHUB=1

ensure_github_user() {
  if [ -n "${GITHUB_USER-}" ]; then
    return
  fi
  GITHUB_USER=$(git remote get-url origin | sed 's#.*github.com/\([^/]*\)/.*#\1#')
}
