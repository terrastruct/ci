#!/bin/sh
set -eu
cd -- "$(dirname "$0")/.."
cd ./lib
. ./job.sh
cd - >/dev/null

job_parseflags "$@"
runjob log ./lib/log_test.sh &
runjob flag ./lib/flag_test.sh &
waitjobs
