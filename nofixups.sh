#!/bin/sh
set -eu
cd -- "$(dirname "$0")/lib"
. ./git.sh
cd - >/dev/null

commits="$(git log --grep='fixup!' --format=%h ${GIT_BASE:+"$GIT_BASE..HEAD"})"
if [ -n "$commits" ]; then
  echo "$commits" | logpcat 'fixup detected'
  exit 1
fi
