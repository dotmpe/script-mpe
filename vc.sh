
test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${stat:-exit} $?
uc_script_load user-script || ${stat:-exit} $?

# Use alsdefs set to cut down on small multiline boilerplate bits.
#user_script_alsdefs
! script_isrunning "vc" .sh ||
  ALIASES=1 user_script_shell_mode || ${stat:-exit} $?


### Vc:


## Main command handlers



## User-script parts

vc_maincmds="names var-names"
vc_shortdescr='Split and assemble file names and strings from patterns'

vc_aliasargv ()
{
  test -n "${1:-}" || return
  case "${1//_/-}" in

    ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;
  esac
}

vc_loadenv () # ~ <Cmd-argv...>
{
  #user_script_loadenv || return
  : "${_E_not_found:=127}"
  : "${_E_next:=196}"
  user_script_baseless=true \
  script_part=${1:?} user_script_load groups || {
      # E:next means no libs found for given group(s).
      test ${_E_next:?} -eq $? || return $_
    }
  lib_load "${base}" &&
  lib_init "${base}" || return
  lk="$UC_LOG_BASE"
  $LOG notice "$lk:loadenv" "User script loaded" "[-$-] (#$#) ~ ${*@Q}"
}

# Main entry (see user-script.sh for boilerplate)

! script_isrunning "vc" .sh || {
  export UC_LOG_BASE="$SCRIPTNAME.sh[$$]"
  user_script_load || exit $?
  script_defcmd=check
  user_script_defarg=defarg\ aliasargv
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
