#!/usr/bin/env bash


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
  # TODO: define fallback for everything else?
  #( * ) shift; set -- outline "$@" ;;
  esac
}


# Main entry (see user-script.sh for boilerplate)

outline_sh_name=Outline.sh
outline_sh_version=0.0.0-alpha
outline_sh_shortdescr=""
outline_sh_maincmds=""
outline_sh_defcmd=fetch

us-env -r us:boot.screnv &&

us-env -r user-script || ${us_stat:-exit} $?

! script_isrunning "outline.sh" || {
  user_script_load || exit $?

  # To extract aliases for help
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"

  script_run "$@"
}
#
