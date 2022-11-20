#!/bin/sh
if [ "${LIB_MAKE-}" ]; then
  return 0
fi
LIB_MAKE=1
. ./log.sh
. ./git.sh

_make() {
  if [ "${CI:-}" ]; then
    if ! is_changed .; then
      return
    fi
    if [ "${GITHUB_TOKEN:-}" ]; then
      git config --global credential.helper store
      cat > ~/.git-credentials <<EOF
https://cyborg-ts:$GITHUB_TOKEN@github.com
EOF
    fi
    git submodule update --init --recursive
  fi
  if [ -z "${MAKE_LOG:-}" ]; then
    CI_MAKE_ROOT=1
    export MAKE_LOG="./.make-log"
    # set +e
    # if [ -t 1 ]; then
    #   # runtty is necessary to allow make to write its output unbuffered. Otherwise the
    #   # output is printed in surges as the write buffer is exceeded rather than a continous
    #   # stream. Remove the runtty prefix to experience the laggy behaviour without it.
    #   runtty make -sj8 "$@" \
    #     | tee /dev/stderr "$MAKE_LOG" \
    #     | stripansi > "$MAKE_LOG.txt"
    # else
    #   make -sj8 "$@" \
    #     | tee /dev/stderr "$MAKE_LOG" \
    #     | stripansi > "$MAKE_LOG.txt"
    # fi
  else
    CI_MAKE_ROOT=0
    # set +e
    # make -sj8 "$@"
  fi

  set +e
  make -sj8 "$@"
  code="$?"
  set -e
  if [ "$code" -ne 0 ]; then
    notify "$code"
    return "$code"
  fi
  # Make sure nothing has changed
  if [ -n "${CI-}" ] && ! git_assert_clean; then
    notify 1
    return 1
  fi
  notify 0
}
