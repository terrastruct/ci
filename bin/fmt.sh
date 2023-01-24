#!/bin/sh
set -eu
cd -- "$(dirname "$0")/../lib"
. ./log.sh
. ./git.sh
. ./job.sh
. ./misc.sh
cd - >/dev/null

PATH="$(cd -- "$(dirname "$0")" && pwd)/../bin:$PATH"

mdtocsubst_xargsd() {
  cd "$(git rev-parse --show-toplevel)"
  sh_c hide xargsd "'\\.md$'" mdtocsubst
}

gomodtidy() {
  sh_c go mod tidy
}

gofmt() {
  cd "$(git rev-parse --show-toplevel)"
  sh_c hide xargsd "'\.go$'" gofmt -s -w
  if search_up go.mod >/dev/null; then
    modname=$(go list -m)
    case $modname in
      github.com/terrastruct/*|oss.terrastruct.com/*)
        GOIMPORTS_LOCAL="${GOIMPORTS_LOCAL:+$GOIMPORTS_LOCAL,}oss.terrastruct.com,github.com/terrastruct";;
      *)
        GOIMPORTS_LOCAL="${GOIMPORTS_LOCAL:+$GOIMPORTS_LOCAL,}$modname";;
    esac
  fi
  sh_c hide xargsd "'\.go$'" go run golang.org/x/tools/cmd/goimports@v0.4.0 -w -local="${GOIMPORTS_LOCAL-}"
}

pkgjson() {
  sh_c yarn "${CI:+--immutable}" "${CI:+--immutable-cache}"
}

prettier() {
  cd "$(git rev-parse --show-toplevel)"
  sh_c hide xargsd "'\.\(js\|jsx\|ts\|tsx\|scss\|css\|html\)$'" npx prettier@2.8.1 --loglevel=warn --print-width=90 --write
}

trailing_whitespace() {
  cd "$(git rev-parse --show-toplevel)"
  sh_c "<\"\$CHANGED_FILES\" grep -v '\.\(pdf\)$' | hide_stderr xargs git grep -Il '' | hide xargs sed -i.sedbak 's/[[:space:]]*$//g'"
  sh_c find . -name "'*.sedbak'" -delete
}

d2fmt() {
  if ! command -v d2 /dev/null && [ -n "${CI-}" ]; then
    curl -fsSL https://d2lang.com/install.sh | sh -s --
  fi
  sh_c XARGS_N=1 hide xargsd "'\.\(d2\)$'" d2 fmt
}

main() {
  job_parseflags "$@"
  ensure_changed_files
  if <"$CHANGED_FILES" grep -v '\.\(pdf\)$' | xargs git grep -qIl '' >/dev/null 2>&1; then
    runjob trailing-whitespace trailing_whitespace
  fi
  if <"$CHANGED_FILES" grep -q '\.\(md\)$'; then
    runjob mdtocsubst mdtocsubst_xargsd &
  fi
  if search_up go.mod >/dev/null; then
    runjob go.mod gomodtidy &
  fi
  if <"$CHANGED_FILES" grep -q '\.\(go\)$'; then
    runjob gofmt &
  fi
  if search_up package.json > /dev/null; then
    runjob package.json pkgjson &
  fi
  if <"$CHANGED_FILES" grep -q '\.\(js\|jsx\|ts\|tsx\|scss\|css\|html\)$'; then
    runjob prettier &
  fi
  if <"$CHANGED_FILES" grep -qm1 '\.\(d2\)$'; then
    runjob d2fmt &
  fi
  waitjobs
}

main "$@"
