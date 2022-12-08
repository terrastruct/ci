#!/bin/sh
set -eu
cd -- "$(dirname "$0")/lib"
. ./git.sh
. ./ci.sh
. ./notify.sh
cd - >/dev/null

capcode nofixups
ci_waitjobs
