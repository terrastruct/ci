#!/bin/sh
set -eu
cd -- "$(dirname "$0")/.."
cd ./lib
. ./job.sh
. ./git.sh
cd - >/dev/null

job_parseflags "$@"
if is_changed ./lib/test.sh ./lib/rand.sh ./lib/log.sh; then
  runjob log ./lib/log_test.sh &
fi
if is_changed ./lib/test.sh ./lib/rand.sh ./lib/log.sh ./lib/flag.sh; then
  runjob flag ./lib/flag_test.sh &
fi
if is_changed \
  ./lib/test.sh ./lib/rand.sh ./lib/log.sh ./lib/git.sh \
  ./lib/flag.sh ./lib/ci.sh ./lib/job.sh ./lib/notify.sh; then
  runjob make ./lib/make_test.sh &
fi
waitjobs
