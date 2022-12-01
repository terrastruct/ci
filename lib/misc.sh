#!/bin/sh
if [ "${LIB_MISC-}" ]; then
  return 0
fi
LIB_MISC=1
. ./log.sh

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
  pandoc -s --toc --from gfm --to gfm | awk '/-/{f=1} {if (!NF) exit; print}'
}

tocsubst() {
  while flag_parse "$@"; do
    case "$FLAG" in
      h|help)
        help
        cat <<EOF
usage: $0 [--skip n] README.md
EOF
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

  SKIP=${SKIP:-0}

  TOC=$(sh_c "<$1 pandoc_toc" | sed -E -e "/^ {0,$SKIP}-/d" -e "s/^$(repeat ' ' $((SKIP*2)))//")
  TOC_START=$(<"$1" grep -Fn '<!-- toc -->' | cut -d: -f1 | head -n1)
  BEFORE_TOC=$(<"$1" head -n"$(( TOC_START ))")
  AFTER_TOC=$(<"$1" tail +"$(( TOC_START+1 ))")
  TOC_END=$(echo "$AFTER_TOC" | grep -nm 1 '^$' | cut -d: -f1 | head -n1)
  TOC_END=$(( TOC_START + TOC_END ))
  AFTER_TOC=$(<"$1" tail +"$(( TOC_END ))")
  echo "$BEFORE_TOC" >"$1"
  echo "$TOC" >>"$1"
  echo "$AFTER_TOC" >>"$1"
}
