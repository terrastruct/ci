#!/bin/sh
set -eu
cd -- "$(dirname "$0")/.."
cd ./lib
. ./log.sh
cd - >/dev/null

sh_c chmod +w lib.sh
sh_c \>lib.sh
find lib -name '*.sh' ! -name '*_test.sh' | sort | while read fname; do
  # Remove lines for sourcing dependency lib/*.sh files as all files are bundled into
  # lib.sh and so all dependencies will be satisfied. The individual files will not exist
  # when distributing just lib.sh and so sourcing will fail anyway.
  sh_c sed '"/^\. /d"' "$fname" \>\>lib.sh
done
sh_c chmod -w lib.sh
