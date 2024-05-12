#!/usr/bin/env bash

test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${us_stat:-exit} $?

uc_script_load user-script || ${us_stat:-exit} $?

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

file_maincmds=""
file_shortdescr=""

file_aliasargv ()
{
  test -n "${1:-}" || return ${_E_MA:?}
  case "${1//_/-}" in
  ( "-?"|-h|h|help|user-script-help ) shift; set -- user_script_help "$@" ;;
    * ) set -- file_ "$@"
  esac
}

# Main entry (see user-script.sh for boilerplate)

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script

! script_isrunning "file" .sh || {
  export UC_LOG_BASE="${SCRIPTNAME}[$$]"
  user_script_load defarg || exit $?
  # Default value used if argv is empty
  script_defcmd=short
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
