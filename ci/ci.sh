#!/bin/sh
set -eu
cd -- "$(dirname "$0")/.."
cd ./lib
. ./job.sh
. ./ci.sh
cd - >/dev/null

ensure_git_base
job_parseflags "$@"
runjob gen ./ci/gen.sh &
runjob test ./ci/test.sh &
ci_waitjobs
