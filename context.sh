#!/bin/sh
CMD_ARG=$_


context_files ()
{
  local act="${1:-list}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:files:$act
  case "$act" in
    ( a|all )
          files_existing ".meta/stat/index/{context,ctx}{,-*}.list"
        ;;
    ( l|ls|list )
        context_files c
        find .meta/stat/index -iname 'ctx-*.list' ;;
    ( c|check )
        test ! -e .meta/stat/index/context.list ||
            $LOG warn "$lk" "Should not have context.list" ;;
    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

context_status ()
{
  local act="${1:-short}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:status
  case "$act" in
    ( s|short )
            context_files check
            wc -l $(context_files a)
        ;;
    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}


## User-script parts

#context_sh_name=foo
#context_sh_version=xxx
context_sh_maincmds="help short version"
#context_sh_shortdescr=''

context_sh_aliasargv ()
{
  case "$1" in
      ( s|short ) shift; set -- context_status short ;;
      ( f|files ) shift; set -- context_files "$@" ;;
      ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;
  esac
}

#context_sh_loadenv ()
#{
#  shopt -s nullglob
#}
#
#context_sh_unload ()
#{
#  shopt -u nullglob
#}


# Main entry (see user-script.sh for boilerplate)

test -n "${user_script_loaded:-}" || {
  set -e
  . "${US_BIN:="$HOME/bin"}"/user-script.sh &&
      user_script_shell_env
}

! script_isrunning "context.sh" || {
  # Default value used if argv is empty
  script_defcmd=short
  # To include all aliases for user_script_defarg
  script_fun_xtra_defarg=context_sh_aliasargv
  # To extract aliases for help
  script_xtra_defarg=context_sh_aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"
}

script_entry "context.sh" "$@"
#
