#!/bin/sh
if [ "${LIB_MISC-}" ]; then
  return 0
fi
LIB_MISC=1
. ./log.sh
. ./flag.sh
. ./release.sh

aws() {
  # Without the redirection aws's cli will write directly to /dev/tty bypassing prefix.
  command aws "$@" > /dev/stdout
}

docker_run() {
  sh_c docker run --rm \
    -v "$HOME:$HOME" \
    -w "$HOME" \
    -e HOME \
    -e TERM \
    -e COLOR \
    -u "$(id -u):$(id -g)" \
    "$@"
}

pandoc_toc() {
  if [ -n "${CI-}" ] && ! command -v pandoc >/dev/null; then
    VERSION=2.19.2
    ensure_arch
    export DEBIAN_FRONTEND=noninteractive
    cd "$(mktemp -d)"
    sh_c curl -fssLO "https://github.com/jgm/pandoc/releases/download/$VERSION/pandoc-$VERSION-1-$ARCH.deb"
    sh_c sudo dpkg -i "pandoc-$VERSION-1-$ARCH.deb" >&2
    cd - >/dev/null
  fi
  pandoc --wrap=none -s --toc --from gfm --to gfm | awk '/-/{f=1} {if (!NF) exit; print}'
}

mdtocsubst_help() {
  cat <<EOF
usage: mdtocsubst [--skip n] README.md ...
EOF
}

mdtocsubst() {
  while flag_parse "$@"; do
    case "$FLAG" in
      h|help)
        mdtocsubst_help
        return 0
        ;;
      skip)
        flag_nonemptyarg && shift "$FLAGSHIFT"
        SKIP=$FLAGARG
        ;;
      *)
        flag_errusage "unrecognized flag $FLAGRAW"
        ;;
    esac
  done
  shift "$FLAGSHIFT"

  SKIP=${SKIP:-1}

  if [ $# -eq 0 ]; then
    flag_errusage "At least one input file is required."
    return 1
  fi

  while [ $# -gt 0 ]; do
    TOC=$(<"$1" pandoc_toc)
    if [ "$SKIP" -gt 0 ]; then
      TOC=$(echo "$TOC" | sed -E -e "/^ {0,$(((SKIP-1)*2))}-/d" -e "s/^ {0,$((SKIP*2))}//")
    fi
    TOC_START=$(<"$1" grep -Fn '<!-- toc -->' | cut -d: -f1 | head -n1)
    if [ -z "$TOC_START" ]; then
      return 0
    fi
    BEFORE_TOC=$(<"$1" head -n"$((TOC_START))")
    AFTER_TOC=$(<"$1" tail +"$((TOC_START+1))")
    TOC_END=$(echo "$AFTER_TOC" | grep -nm 1 '^$' | cut -d: -f1 | head -n1)
    TOC_END=$((TOC_START+TOC_END))
    AFTER_TOC=$(<"$1" tail +"$TOC_END")
    echo "$BEFORE_TOC" >"$1"
    echo "$TOC" >>"$1"
    echo "$AFTER_TOC" >>"$1"
    shift
  done
}
