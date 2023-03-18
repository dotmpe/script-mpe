#!/usr/bin/env bash

### Half duplex single fifo client-server script

# This could be a really simple IPC setup for shell scripting
# a server with one client at a time, and a single line for request and
# then one back for the answer.

# Helper for BG_FIFO env. Create or check for named pipe path.
bg_fifo_single () # ~ [ <Create> [ <Exists> ]]
{
  true "${BG_FIFO:=$BG_RUND.fifo}"

  { test $# -eq 0 || "${1:-true}"; } && {

    test -p "$BG_FIFO" && {
      return
    } || {
      echo "Creating named pipe at '$BG_FIFO'" >&2
      #test ! -e "$BG_FIFO" || rm "$BG_FIFO"
      mkfifo "$BG_FIFO" || return $?
    }

  } || {

    { test $# -le 1 || "${2:-true}"; } && {
      test -p "$BG_FIFO" || {
        echo "! $0: No such named pipe '$BG_FIFO'" >&2
        return 1
      }
    } || {
      ! test -p "$BG_FIFO" || {
        echo "! $0: Named pipe exists at '$BG_FIFO'" >&2
        return 1
      }
    }
  }
}

bg_main_boot ()
{
  set -eu
  #set -m
  #shopt -s checkjobs

  . "${U_C:?}/script/shell-uc.lib.sh" &&
  shell_uc_lib_load && shell_uc_lib_init || {
    $LOG error : "Shell uc init failed" E$? $? || return
  }

  . ~/bin/bg.lib.sh &&
  bg_lib_load || {
    $LOG error : "bg load failed" E$? $? || return
  }
}

bg_main_single ()
{
  bg_main_boot || return

  true "${BG_PID:=$BG_RUND.pid}"

  case "${1:-server}" in

    # Defer to bg-proc:* handler, for ops on bg process from current terminal
    bg ) shift; local act=${1:?}; shift
      declare -f "bg_proc__${act//-/_}" >/dev/null 2>&1 || {
        echo "! $0: no such inspector: $act"
        return 1
      }
      bg_proc__${act//-/_} "$@" || return
    ;;

    # Drop new command for bg proc. See bg-handle:* for command handlers.
    c|bg-cmd ) shift; local cmd_handler=${1:?}; shift
      echo "${cmd_handler//-/_}" "${@@Q}" > "$BG_FIFO"
    ;;

    env )
      echo "BG_RUND=$BG_RUND"
      echo "BG_PID=$BG_PID"
      echo "BG_FIFO=$BG_FIFO"
    ;;

    # Shortcut to run (isolated) eval command at bg
    re ) shift
      $0 bg-cmd eval-run "${@:?}"
    ;;

    # Shortcuts for isolated commands that give output
    rE ) shift
      $0 req eval-run "${@:?}"
    ;;
    req ) shift
      $0 bg-cmd "${@:?}"
      cat "$BG_FIFO";echo
    ;;

    # Run server: read command lines at BG_FIFO and respond with std{out,err}
    # length and content separated by FS (ASCII file-separator)
    server )
      bg_fifo_single true || return
      echo "Starting server ($$)" >&2
      test $# -eq 0 || { # Update PID if requested
        test 0 = "${1:-}" || {
          #test -e "$BG_PID" || {
            echo "$$" > "$BG_PID"
          #}
        }
      }
      bg_recv_blocking "$BG_FIFO" || fail=true
      rm "$BG_FIFO"
      ! ${fail:-false} || return $?
    ;;

    start )
      $0 server &
      echo "$!" > "$BG_PID"
    ;;

    s|st|stat|status )
      # More sysfs kernel info for process: ls -la /proc/$PID
      $0 bg check || return
      $0 bg tree || return
      $0 bg pwd || return
    ;;

    d|details )
      $0 bg details || return
    ;;

    * ) $0 bg "$@" ;;

  esac
}

# XXX: see bg-main-single
bg_main_multi ()
{
  bg_main_boot || return

  #true "${BG_TAG:=default}"
  #true "${BG_PID:=$BG_RUND-${BG_TAG:?}.pid}"

  case "${1:-server}" in

      env )
        ;;

      purge-all-servers )
          ! pgrep -cf $(basename "$0")\ server >/dev/null ||
              $0 kill-all-servers || return
          $0 cleanup
        ;;

      kill-all-servers )
          pkill -f $(basename "$0")\ server || return
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
    ( bg-simple ) bg_main_single "$@" ;;
esac
#
