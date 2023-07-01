
### Half duplex single fifo client-server script

# This could be a really simple IPC setup for shell scripting
# a server with one client at a time, and a single line for request and
# then one back for the answer.


at_bg () # ~ <scr-ctx> <bg-cmd...>
{
  bg_main_boot &&
  bg_init ${1:-} ||
    $LOG error "$BG_BASE:$0[$$]" "bg script init" "E$?" $? || return
  std_quiet declare -F at_bg_${1:-} || shift # set -- "${@:2}"
  at_bg_${1:-simple} "${@:2}"
}

at_bg_simple () # ~ <bg-cmd...>
{
  BG_FIFO=$BG_RUNB.fifo
  bgctx=bg_main_single
  : "${bgscr:=$0}"
  $bgctx "$@"
}

# Helper for BG_FIFO env. Create or check for named pipe path.
bg_fifo_create () # ~
{
  test ! -e "$BG_FIFO" || {
    $LOG error "$lk" "Path for named pipe exists" "$BG_FIFO" 1 || return
    #rm "$BG_FIFO"
  }
  $LOG info "$lk" "Creating named pipe" "$BG_FIFO"
  mkfifo "$BG_FIFO" || return
}

bg_fifo_exists () # ~
{
  test -p "$BG_FIFO" || {
    $LOG error "$lk" "No such named pipe" "$BG_FIFO" 1 || return
  }
}

bg_main_boot ()
{
  sh_mode strict || return
  #set -eu
  #o pipefail
  #set -m
  #shopt -s checkjobs
  if_ok "${ENV_SRC:=$(realpath "$(command -v $0)")}" || return
  lib_loaded shell-uc bg || {
    lib_require shell-uc bg &&
    lib_init || return
  }
  #: "${BG_TAG:=default}"
  #: "${BG_PID:=$BG_RUNB-${BG_TAG:?}.pid}"
}

bg_main_single ()
{
  local act=${1:-}
  test 0 -eq $# || shift
  case "$act" in

    # Defer to bg-proc:* handler, for ops on bg process from current terminal
    proc ) local ph=${1:?}; shift
      sh_fun "bg_proc__${ph//-/_}" || {
        $LOG error "$lk:proc" "no such inspector" "$ph" 1 || return
      }
      bg_fifo_exists &&
      bg_proc__running ||
        $LOG error ":proc:bg[$$]" "No instance" "E$?:$BG_BASE" 1 || return
      bg_proc__${ph//-/_} "$@" || return
    ;;

    # Drop new command for bg proc. See bg-handle:* for command handlers.
    #cmd ) shift; bg_proc__cmd "$@" ;;

    env ) # ~ (base|scache|...) # Print declarations, typesets and script lines
      case ${1:-base} in
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
          $bgctx env base &&
          declare -f bg_proc__{cmd,run,run_cmd,read_std_response} &&
          printf 'bg_proc__run_cmd "$@"\n'
        ;;
        ( run-eval )
          $bgctx env base &&
          declare -f bg_proc__{cmd,run,run_eval,read_response} &&
          printf 'bg_proc__run_eval "$@"\n'
        ;;
        ( cmd )
          $bgctx env base &&
          declare -f bg_proc__cmd &&
          printf 'bg_proc__cmd "$@"\n'
        ;;
        ( pid )
            $bgctx env base &&
            declare -f bg_proc__pid &&
            printf 'PID=$(<$BG_PID) &&' &&
            printf 'bg_proc__pid "$@"\n'
          ;;
        #( stop )
        #    $bgctx env base &&
        #    declare -f bg_proc__stop &&
        #    printf 'bg_proc__stop "$@"\n'
        #  ;;
      esac
    ;;

    # Shortcut to just read last response
    rr ) bg_proc__read_response ;;

    # Routine to parse eval-run reponse back to stat/out/err
    rrr ) bg_proc__read_std_response ;;

    init )
      for scr in run-cmd run-eval pid stop cmd
      do
        $bgctx env $scr >| ${BG_CACHE:?}/status-$scr.sh
      done
    ;;
    scache ) local scr=${1:?}
      test 0 -eq $# || shift
      . ${BG_CACHE:?}/status-$scr.sh
    ;;

    start )
      $0 server &
      #echo "$!" > "$BG_PID"
    ;;

    s|st|stat|status )
      #$bgctx proc check &&
      #$bgctx proc tree &&
      $bgctx ps &&
      $bgctx run-eval lib_require lib-uc &&
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
$($bgctx run-cmd lib_uc_hook pairs _lib_loaded | sed 's/^/    /' )
  Lib-init:
$($bgctx run-cmd lib_uc_hook pairs _lib_init | sed 's/^/    /' )
EOM
    ;;

    "" ) # ~ # Default action, and aliases.
      bg_proc__running &&
        set -- ps "$@" ||
        set -- list "$@"
      $bgctx "$@" ;;

    * )
      sh_fun "bg__${act//-/_}" && {
        "$_" "$@"
        return
      }
      $bgctx proc "$act" "$@" ;;

  esac
}

# XXX: see bg-main-single
bg_main_multi ()
{
  bg_main_boot || return

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
