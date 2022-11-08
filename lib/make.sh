#!/bin/sh

if [ "${_LIB_MAKE:-}" ]; then
  return
fi
_LIB_MAKE=1

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
    set +e
    # runtty is necessary to allow make to write its output unbuffered. Otherwise the
    # output is printed in surges as the write buffer is exceeded rather than a continous
    # stream. Remove the runtty prefix to experience the laggy behaviour without it.
    runtty make -sj8 "$@" \
      | tee /dev/stderr "$MAKE_LOG" \
      | stripansi > "$MAKE_LOG.txt"
  else
    CI_MAKE_ROOT=0
    set +e
    make -sj8 "$@" 2>&1
  fi

  code="$?"
  set -e
  if [ "$code" -ne 0 ]; then
    notify "$code"
    return "$code"
  fi
  # make doesn't return a nonsuccess exit code on recipe failures.
  if <"$MAKE_LOG" grep -q 'make.* \*\*\* .* Error'; then
    notify 1
    return 1
  fi
  if [ -n "${CI:-}" ]; then
    # Make sure nothing has changed
    if ! git -c color.ui=always diff --exit-code; then
      notify 1
      return 1
    fi
  fi
  notify 0
}
