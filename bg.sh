#!/usr/bin/env bash

### Half duplex single fifo client-server script

# This could be a really simple IPC setup for shell scripting
# a server with one client at a time, and a single line for request and
# then one back for the answer.


at_bg ()
{
  bg_main_boot &&
  bg_init ${1:-} ||
    $LOG error "$BG_BASE:$0[$$]" "bg script init" "E$?" $? || return
  std_quiet declare -F at_bg_${1:-} || shift # set -- "${@:2}"
  at_bg_${1:-simple} "${@:2}"
}

at_bg_simple ()
{
  BG_FIFO=$BG_RUNB.fifo
  bgctx=bg_main_single
  : "${bgscr:=$0}"
  $bgctx "$@"
}

# Helper for BG_FIFO env. Create or check for named pipe path.
bg_fifo_single () # ~ [ <Create> [ <Exists> ]]
{
  true "${BG_FIFO:=$BG_RUNB.fifo}"

  { test $# -eq 0 || "${1:-true}"; } && {

    test -p "$BG_FIFO" && {
      return
    } || {
      test ! -e "$BG_FIFO" || {
        $LOG error : "Path exists" "$BG_FIFO" 1 || return
        #rm "$BG_FIFO"
      }
      $LOG info : "Creating named pipe" "$BG_FIFO"
      mkfifo "$BG_FIFO" || return
    }

  } || {

    { test $# -le 1 || "${2:-true}"; } && {
      test -p "$BG_FIFO" || {
        $LOG error : "No such named pipe" "$BG_FIFO"
        return 1
      }
    } || {
      ! test -p "$BG_FIFO" || {
        $LOG error : "Named pipe exists" "$BG_FIFO"
        return 1
      }
    }
  }
}

bg_main_boot ()
{
  set -eu
  #o pipefail
  #set -m
  #shopt -s checkjobs
  : "${ENV_SRC:=$(realpath "$(command -v $0)")}"
  lib_require shell-uc bg &&
  lib_init
}

bg_main_single ()
{
  case "${1:-instance}" in

    # Defer to bg-proc:* handler, for ops on bg process from current terminal
    proc ) shift; local act=${1:-instance}; test 0 -eq $# || shift
      declare -f "bg_proc__${act//-/_}" >/dev/null 2>&1 || {
        echo "! $0: no such inspector: $act"
        return 1
      }
      bg_proc__${act//-/_} "$@" || return
    ;;

    # Drop new command for bg proc. See bg-handle:* for command handlers.
    #cmd ) shift; bg_proc__cmd "$@" ;;

    env )
      case ${2:-base} in
        ( base ) declare -p BG_{RUNB,PID,FIFO} ;;
        ( scache )
          cat <<EOM
#!/usr/bin/env bash
scr=\${1:?}
shift
. ${BG_CACHE:?}/status-\$scr.sh
EOM
        ;;
        ( run-cmd )
          $bgctx env cmd &&
          declare -f bg_proc__{run,run_cmd,read_std_response} &&
          printf 'bg_proc__run_cmd "$@"\n'
        ;;
        ( run-eval )
          $bgctx env cmd &&
          declare -f bg_proc__{run,run_eval,read_response} &&
          printf 'bg_proc__run_eval "$@"\n'
        ;;
        ( cmd )
          $bgctx env base &&
          declare -f bg_proc__cmd &&
          printf 'bg_proc__cmd "$@"\n'
        ;;
      esac
    ;;

    # Shortcut to just read last response
    rr ) bg_proc__read_response ;;

    # Routine to parse eval-run reponse back to stat/out/err
    rrr ) bg_proc__read_std_response ;;

    clean ) shift; bg_proc__clean "$@" ;;
    server ) shift; bg_proc__server "$@" ;;

    init )
      for scr in run-cmd run-eval cmd
      do
        $bgctx env $scr >| ${BG_CACHE:?}/status-$scr.sh
      done
    ;;
    scache ) local scr=${2:?}
      shift 2
      . ${BG_CACHE:?}/status-$scr.sh
    ;;

    start )
      $0 server &
      #echo "$!" > "$BG_PID"
    ;;

    s|st|stat|status )
      #$bgctx proc check &&
      #$bgctx proc tree &&
      $bgctx instance &&
      $bgctx run-eval lib_require uc-lib &&
      cat <<EOM
  Base: $BG_BASE
  PWD: $($bgctx proc pwd)
  TTY: $($bgctx run-cmd tty)
  FD: $($bgctx run-cmd eval ls -go --time-style=+%s /proc/\$\$/fd | cut -d' ' -f5- |
sed 's/^/    /' )
  Env: $($bgctx run-cmd set | wc -c) bytes
    $($bgctx run-cmd compgen -A alias | wc -l) aliases
    $($bgctx run-cmd compgen -A arrayvar | wc -l) arrays
    $($bgctx run-cmd compgen -A function | wc -l) functions
    $($bgctx run-cmd compgen -A variable | wc -l) variables
  Export: $($bgctx run-cmd env | wc -c) bytes
    $($bgctx run-cmd compgen -A export | wc -l) variables
EOM
      # More sysfs kernel info for process:
      #ls -la /proc/$(<$BG_PID)
    ;;

    us-stat )
      cat <<EOM
  Env-src:
    $($bgctx run-cmd eval echo \${ENV_SRC:-} )
  Env-lib:
    $($bgctx run-cmd eval echo \${ENV_LIB:-} )
  Lib-loaded:
$($bgctx run-cmd uc_lib_hook pairs _lib_loaded | sed 's/^/    /' )
  Lib-init:
$($bgctx run-cmd uc_lib_hook pairs _lib_init | sed 's/^/    /' )
EOM
    ;;

    * )
      bg_proc__running ||
        $LOG error : "No instance" "$BG_BASE" 1 || return
      $bgctx proc "$@" ;;

  esac
}

# XXX: see bg-main-single
bg_main_multi ()
{
  bg_main_boot || return

  #true "${BG_TAG:=default}"
  #true "${BG_PID:=$BG_RUNB-${BG_TAG:?}.pid}"

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

    ( bg-simple ) at_bg "" "simple" "$@" ;;
esac
#
