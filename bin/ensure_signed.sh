#!/bin/sh
set -eu
cd -- "$(dirname "$0")/../lib"
. ./git.sh
cd - >/dev/null

ensure_signed
