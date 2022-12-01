#!/bin/sh
set -eu
cd -- "$(dirname "$0")/lib"
. ./git.sh
. ./notify.sh
cd - >/dev/null

capcode nofixups
notify "$code"
exit "$code"
