#!/bin/sh
set -eu
cd -- "$(dirname "$0")/lib"
. ./git.sh
. ./notify.sh
cd - >/dev/null

if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
  git fetch --unshallow origin master
fi

set_git_base
commits="$(git log --grep='fixup!' --format=%h ${GIT_BASE:+"$GIT_BASE..HEAD"})"
if [ -n "$commits" ]; then
  echo "$commits" | FGCOLOR=1 logpcat 'fixup detected'
  notify 1
  exit 1
fi