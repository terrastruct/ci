#!/bin/sh
set -eu
. "$(dirname "$0")/../lib.sh"

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
  while :; do
    flag_parse "$@"
    case "$FLAG" in
      h|help)
        help
        return 0
        ;;
      version)
        flag_nonemptyarg && shift "$FLAGSHIFT"
        VERSION=$FLAGARG
        ;;
      '')
        shift "$FLAGSHIFT"
        break
        ;;
      *)
        flag_errusage "unrecognized flag $FLAGRAW"
        ;;
    esac
  done

  VERSION=${VERSION:-$(git describe 2>/dev/null)}
  if [ -z "${VERSION-}" ]; then
    echoerr "no --version passed and unable to determine version from git describe"
    return 1
  fi

  sh_c gh release upload "${REPO+"-R \"$REPO\""}" --clobber "$VERSION" "./ci/release/build/$VERSION"/*.tar.gz
}

main "$@"
