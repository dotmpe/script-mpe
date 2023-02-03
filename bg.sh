#!/usr/bin/env bash

### Half duplex single fifo client-server script

# This could be a really simple IPC setup for shell scripting
# a server with one client at a time, and a single line for request and
# then one back for the answer.

set -eu
bg_sock=/tmp/bash-bg.sock
test -p "$bg_sock" && {
    echo "Socket exists at '$bg_sock'" >&2
}
. ~/bin/bg.lib.sh

case "${1:-client1}" in

    socketclient )
          bg_writeread "${*@Q}"
          exit $?
        ;;

    server1 ) be_entry=$1
          test -p "$bg_sock" || {
            echo "Creating socket at '$bg_sock'" >&2
            #test ! -e "$bg_sock" || rm "$bg_sock"
            mkfifo "$bg_sock" || exit $?
          }
          echo "Starting server ($$)" >&2
          bg_recv_blocking "$bg_sock" || fail=true
          rm "$bg_sock"
          ! ${fail:-false} || exit $?
        ;;

    * ) echo "? $1" >&2
        ;;

esac
#
