#!/bin/sh
set -eu
cd -- "$(dirname "$0")/.."
cd ./lib
. ./job.sh
. ./ci.sh
cd - >/dev/null

fmtgen() {
  runjob fmt ./bin/fmt.sh
  runjob gen ./ci/gen.sh
}

job_parseflags "$@"
ensure_git_base
if is_changed lib; then
  fmtgen &
  runjob test ./ci/test.sh &
fi
ci_waitjobs
