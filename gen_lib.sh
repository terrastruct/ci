#!/bin/sh
set -eu
cd -- "$(dirname "$0")"

find lib -name '*.sh' ! -name 'all.sh' ! -name '*_test.sh' | xargs cat > lib.sh
