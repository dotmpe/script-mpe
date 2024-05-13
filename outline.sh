#!/bin/sh


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

  ( * ) $LOG error "$lk" "No such action" "$1" ${_E_nsa:-68}
  esac
}



# Read out just the '##' prefixed lines from a source
outline_fetch () # ~ <Src>
{
  grep ${grep_f:-} '^###* ' "${1:?"Expected file or -"}"
}

# First '##' prefixed line
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

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script

! script_isrunning "outline.sh" || {
  user_script_load || exit $?

  # Default value used if argv is empty
  script_defcmd=fetch
  # To extract aliases for help
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"

  script_entry "$@"
}
#
