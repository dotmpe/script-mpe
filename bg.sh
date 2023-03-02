#!/usr/bin/env bash

### Half duplex single fifo client-server script

# This could be a really simple IPC setup for shell scripting
# a server with one client at a time, and a single line for request and
# then one back for the answer.

bg_check_fifo ()
{
  ! test -p "$bg_fifo" || {
      echo "! $0: Socket exists at '$bg_fifo' (ignored)" >&2
  }
}

bg_main ()
{
  set -eu

  . ~/bin/bg.lib.sh &&
  bg_lib_load || return

  bg_check_fifo

  case "${1:-server1}" in

      * ) echo "? '$1'" >&2
          ;;
  esac
}

bg_main_multi ()
{
  set -eu

  . "${U_C:?}/script/shell-uc.lib.sh" &&
  shell_uc_lib_load && shell_uc_lib_init || {
    $LOG error : "Shell uc init failed" E$? $? || return
  }

  . ~/bin/bg.lib.sh &&
  bg_lib_load || {
    $LOG error : "bg load failed" E$? $? || return
  }

  bg_check_fifo

  case "${1:-server1}" in

      cleanup )
          shopt -s nullglob
          set -- "${bg_rund}"*.sock "${bg_rund}"*.pid
          test $# -eq 0 || rm "$@"
          shopt -u nullglob
        ;;

      purge-all-servers )
          ! pgrep -cf $(basename "$0")\ server >/dev/null ||
              $0 kill-all-servers || return
          $0 cleanup
        ;;

      kill-all-servers )
          pkill -f $(basename "$0")\ server || return
        ;;

      run )
          shift
          echo "Run: $*" >&2
          echo "$*" > "$bg_fifo"
          #echo "Response:" >&2
          #cat /tmp/bash-bg.sock
          echo "-------------------" >&2
        ;;

      start )
          $0 server1 &
        ;;

      server2 ) be_entry=$1
          bg_fifo=$bg_rund-$$.sock
          shift
          test $# -gt 0 || set -- $be_entry
          test ! -e "${bg_rund}-$1.pid" || {
            echo "PID file for '$1' exists" >&2
            return 1
          }
          test -p "$bg_fifo" || {
            echo "Creating socket at '$bg_fifo'" >&2
            mkfifo "$bg_fifo" || return $?
          }
          echo "$$" | tee "${bg_rund}-$1.pid"
          echo "Starting server ($$)" >&2
          bg_recv_blocking "$bg_fifo" || fail=true
          rm "$bg_fifo"
          ! ${fail:-false} || return $?
        ;;

      server1 ) be_entry=$1
            test -p "$bg_fifo" || {
              echo "Creating socket at '$bg_fifo'" >&2
              #test ! -e "$bg_fifo" || rm "$bg_fifo"
              mkfifo "$bg_fifo" || return $?
            }
            echo "Starting server ($$)" >&2
            bg_recv_blocking "$bg_fifo" || fail=true
            rm "$bg_fifo"
            ! ${fail:-false} || return $?
          ;;

      * ) echo "? $0[$$]: '$1'" >&2
          ;;

  esac
}

bg_main_old ()
{
  case "${1:-server1}" in

      socketclient )
          bg_writeread "${*@Q}" || return
        ;;

      * ) echo "? '$1'" >&2
          ;;

  esac
}


case "$(basename -- "$0" .sh)" in
    ( bg ) bg_main_multi "$@" ;;
    ( bg-simple ) bg_main "$@" ;;
esac
#
