#!/usr/bin/env bash

test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${us_stat:-exit} $?

uc_script_load user-script || ${us_stat:-exit} $?

! script_isrunning "class.sh" ||
  uc_script_load us-als-mpe || ${us_stat:-exit} $?

class_sh__grp=user-script-sh
class_sh__libs=class-uc,lib-uc

class_sh_ ()
{
  local a1_def=summary; sa_switch_arg
  case "$switch" in

    ( [@+]* )
        declare xctx ctxref=local:xctx
        class_init XContext &&
        class_new local:xctx XContext &&
        $xctx$switch &&
        $xctx${1:-.info} "${@:2}"
      ;;

      * ) sa_E_nss
  esac
  __sa_switch_arg
}


## User-script parts

class_sh_maincmds=""
class_sh_shortdescr=""

class_sh_aliasargv ()
{
  test -n "${1:-}" || return ${_E_MA:?}
  case "${1//_/-}" in
    ( "-?"|-h|h|help|user-script-help ) shift; set -- user_script_help "$@" ;;
      * ) set -- class_sh_ "$@"
  esac
}

class_sh_loadenv ()
{
  user_script_loadenv &&
  user_script_initlog || return
  shopt -s nullglob nocaseglob
  sh_mode strict # dev
}

class_sh_unload ()
{
  shopt -u nullglob nocaseglob
}

# Main entry (see user-script.sh for boilerplate)

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script

! script_isrunning "class.sh" || {
  export UC_LOG_BASE="${SCRIPTNAME}[$$]"
  user_script_load defarg || exit $?
  # Default value used if argv is empty
  script_defcmd=short
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
