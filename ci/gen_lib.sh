#!/bin/sh
set -eu
cd -- "$(dirname "$0")/.."
cd ./lib
. ./git.sh
cd - >/dev/null

if [ -n "${CI-}" ]; then
  if ! is_changed lib; then
    return 0
  fi
fi

sh_c \>lib.sh
find lib -name '*.sh' ! -name '*_test.sh' | sort | while read fname; do
  # Remove lines for sourcing dependency lib/*.sh files as all files are bundled into
  # lib.sh and so all dependencies will be satisfied. The individual files will not exist
  # when distributing just lib.sh and so sourcing will fail anyway.
  sh_c sed '"/^\. /d"' "$fname" \>\> lib.sh
done

if [ -n "${CI-}" ]; then
  git_assert_clean
fi
