#!/usr/bin/env bash

us-env -r us:boot.screnv &&

us-env -r user-script || ${us_stat:-exit} $?

! script_isrunning "file" .sh ||
  uc_script_load us-als-mpe || ${us_stat:-exit} $?


file_ ()
{
  local a1_def=summary; sa_switch_arg
  case "$switch" in

  ( ml|modeline )
      lib_require sys os str-uc || return
      declare file{version,id,mode}
      fml_lvar=true file_modeline "$1" &&
      {
        : "file:${1-}"
        : "$_${fileid:+:id=$fileid}"
        : "$_${fileversion:+:ver=$fileversion}"
        : "$_${filemode:+:mode=$filemode}"
        $LOG notice "" "Modeline" "$_"
      }
    ;;

    * ) sa_E_nss
  esac
  __sa_switch_arg
}


## User-script parts

file_name=File.sh
file_version=0.0.0-alpha
#file_shortdescr=""
#file_defcmd=short
#file_maincmds=""

#file_aliasargv ()
#{
#  test -n "${1:-}" || return ${_E_MA:?}
#  case "${1//_/-}" in
#    * ) set -- file_ "$@"
#  esac
#}

# Main entry (see user-script.sh for boilerplate)

! script_isrunning "file" .sh || {
  user_script_load || exit $?
  # Default value used if argv is empty
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
