#!/bin/sh
if [ "${LIB_SSH-}" ]; then
  return 0
fi
LIB_SSH=1
. ./log.sh
. ./flag.sh

ssh_copy_id_help() {
  cat <<EOF
usage: ssh_copy_id -i=id.pub host
EOF
}

ssh_copy_id() {
  while flag_parse "$@"; do
    case "$FLAG" in
      h|help)
        ssh_copy_id_help
        return 1
        ;;
      i)
        flag_nonemptyarg && shift "$FLAGSHIFT"
        ID_PUB_PATH=$FLAGARG
        ;;
      *)
        flag_errusage "unrecognized flag $FLAGRAW"
        ;;
    esac
  done
  shift "$FLAGSHIFT"

  if [ -z "${ID_PUB_PATH-}" ]; then
    flag_errusage "-i for id.pub is mandatory"
  fi

  if [ $# -ne 1 ] ; then
    flag_errusage "only one argument for the remote host is accepted"
  fi

  REMOTE_HOST=${1-}
  sh_c ssh-copy-id -fi "$ID_PUB_PATH" "$REMOTE_HOST"
  sh_c ssh "$REMOTE_HOST" 'cat .ssh/authorized_keys \| sort -u \> .ssh/authorized_keys.dedup'
  sh_c ssh "$REMOTE_HOST" 'cp .ssh/authorized_keys.dedup .ssh/authorized_keys'
  sh_c ssh "$REMOTE_HOST" 'rm .ssh/authorized_keys.dedup'
}

ssh() {
  # Always accept new SSH host keys automatically.
  command ssh -o='StrictHostKeyChecking=accept-new' "$@"
}
