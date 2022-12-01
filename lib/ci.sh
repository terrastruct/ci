#!/bin/sh
if [ "${LIB_CI-}" ]; then
  return 0
fi
LIB_CI=1
. ./log.sh
. ./git.sh

ci_go_fmt() {
	sh_c xargsd '\.go$' gofmt -s -w
	sh_c xargsd '\.go$' go run golang.org/x/tools/cmd/goimports@v0.3.0 \
		-w -local="$(go list -m)"
  if search_up go.mod; then
    sh_c go mod tidy
  fi
}

ci_go_lint() {
  go vet --composites=false ./...
}

ci_go_build() {
  go build ./...
}

ci_go_test() {
  go test "${TESTFLAGS:-./...}"
}

ci_waitjobs() {
  capcode waitjobs
  if [ "$code" = 0 -a -n "${CI-}" ]; then
    capcode git_assert_clean
  fi
  if [ "$code" != 0 ]; then
    notify "$code"
    return "$code"
  fi
  notify 0
  return 0
}
