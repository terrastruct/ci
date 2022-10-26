#!/bin/sh
set -eu
. "$(dirname "$0")/../lib.sh"
PATH="$(cd -- "$(dirname "$0")" && pwd)/../bin:$PATH"

set_changed_files
if search_up go.mod; then
  export CI_FMT_GO_MODULE=1
fi
if search_up package.json; then
  export CI_FMT_NODE_MODULE=1
fi
if < "$CHANGED_FILES" grep -qm1 '\.go$'; then
  export CI_FMT_GO=1
fi
if < "$CHANGED_FILES" grep -qm1 '\.md$'; then
  if [ -z "${CI:-}" ]; then
    # See https://github.com/terrastruct/src/pull/1394
    # Only locally for now.
    export CI_FMT_MARKDOWN=1
  fi
fi
if < "$CHANGED_FILES" grep -qm1 '\.\(js\|jsx\|ts\|tsx\|scss\|css\|html\)$'; then
  export CI_FMT_PRETTIER=1
fi
_make -f "$(dirname "$0")/Makefile" "$@"