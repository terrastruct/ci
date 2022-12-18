#!/bin/sh
set -eu
cd -- "$(dirname "$0")/../lib"
. ./flag.sh
cd - >/dev/null

help() {
  cat <<EOF
usage: $0 --version=<version>

Uploads the assets for release <version> to GitHub.

For example, if <version> is v0.0.99 then it uploads files matching
./ci/release/build/v0.0.99/*.tar.gz to the GitHub release v0.0.99.

Example:
  $0 --version=v0.0.99
EOF
}

main() {
  while flag_parse "$@"; do
    case "$FLAG" in
      h|help)
        help
        return 0
        ;;
      version)
        flag_nonemptyarg && shift "$FLAGSHIFT"
        VERSION=$FLAGARG
        ;;
      *)
        flag_errusage "unrecognized flag $FLAGRAW"
        ;;
    esac
  done
  shift "$FLAGSHIFT"

  VERSION=${VERSION:-$(git describe 2>/dev/null)}
  if [ -z "${VERSION-}" ]; then
    echoerr "no --version passed and unable to determine version from git describe"
    return 1
  fi

  sh_c gh release upload "${REPO+"-R \"$REPO\""}" --clobber "$VERSION" $(find -L "./ci/release/build/$VERSION" -type f -maxdepth 1)
}

main "$@"
