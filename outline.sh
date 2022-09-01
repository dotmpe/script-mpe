#!/bin/sh
CMD_ARG=$_


outline ()
{
  local act="${1:-fetch}"
  test $# -eq 0 || shift
  local lk=${lk:-:outline}:$act
  case "$act" in

    ( g|generate ) # TODO:
          outline=$(outline_fetch "$@")
          expand_sentinel outline "$outline"
        ;;

    ( h|header ) outline_header "$@" ;;
    ( l|fetch ) outline_fetch "$@" ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}



outline_fetch ()
{
  grep ${grep_f:-} '^###* ' "${1:?"Expected file or -"}"
}

outline_header ()
{
  grep_f=-m1 outline_fetch "$@"
}


## User-script parts

#outline_sh_name=foo
#outline_sh_version=xxx
outline_sh_maincmds="help fetch version"
#outline_sh_shortdescr=''

outline_sh_aliasargv ()
{
  case "$1" in
      ( header ) shift; set -- outline_header "$@" ;;
      ( fetch ) shift; set -- outline_fetch "$@" ;;
      ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;

      # TODO: define fallback for everything else?
      #( * ) shift; set -- outline "$@" ;;
  esac
}


# Main entry (see user-script.sh for boilerplate)

test -n "${user_script_loaded:-}" || {
  set -e
  . "${US_BIN:="$HOME/bin"}"/user-script.sh &&
      user_script_shell_env
}

! script_isrunning "outline.sh" || {
  # Default value used if argv is empty
  script_defcmd=fetch
  # To extract aliases for help
  script_xtra_defarg=outline_sh_aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"
}

script_entry "outline.sh" "$@"
#
