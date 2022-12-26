#!/bin/sh
if [ "${LIB_CI-}" ]; then
  return 0
fi
LIB_CI=1
. ./log.sh
. ./git.sh
. ./job.sh
. ./notify.sh

ci_go_lint() {
  go vet --composites=false ./...
}

ci_waitjobs() {
  if [ -z "${CI-}" ]; then
    waitjobs
    return 0
  fi

  capcode waitjobs
  if [ "$code" -ne 0 ]; then
    notify
    return "$code"
  fi
  capcode git_assert_clean
  if [ "$code" -ne 0 ]; then
    notify
    return "$code"
  fi
  capcode nofixups
  notify
  return "$code"
}
