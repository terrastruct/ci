#!/bin/sh
set -eu
cd -- "$(dirname "$0")/../lib"
. ./log.sh
. ./git.sh
. ./job.sh
. ./misc.sh
cd - >/dev/null

PATH="$(cd -- "$(dirname "$0")" && pwd)/../bin:$PATH"

mdtoc() {
  sh_c XARGS_N=1 xargsd "'\\.md$'" mdtocsubst --skip 1
}

gomod() {
  sh_c go mod tidy
}

gofmt() {
  sh_c xargsd "'\.go$'" gofmt -s -w
  if search_up go.mod >/dev/null; then
    GOIMPORTS_LOCAL="${GOIMPORTS_LOCAL-}$(go list -m)"
  fi
  sh_c xargsd "'\.go$'" go run golang.org/x/tools/cmd/goimports@v0.4.0 -w -local="${GOIMPORTS_LOCAL-}"
}

pkgjson() {
  sh_c yarn "${CI:+--immutable}" "${CI:+--immutable-cache}"
}

prettier() {
  sh_c xargsd "'\.\(js\|jsx\|ts\|tsx\|scss\|css\|html\)$'" npx prettier@2.8.1 --print-width=90 --write
}

main() {
  job_parseflags "$@"
  ensure_changed_files
  if <"$CHANGED_FILES" grep -qm1 '\.\(md\)$'; then
    runjob mdtoc &
  fi
  if search_up go.mod >/dev/null; then
    runjob go.mod gomod &
  fi
  if <"$CHANGED_FILES" grep -qm1 '\.\(go\)$'; then
    runjob gofmt gofmt &
  fi
  if search_up package.json > /dev/null; then
    runjob package.json pkgjson &
  fi
  if <"$CHANGED_FILES" grep -qm1 '\.\(js\|jsx\|ts\|tsx\|scss\|css\|html\)$'; then
    runjob prettier prettier &
  fi
  waitjobs
}

main "$@"
