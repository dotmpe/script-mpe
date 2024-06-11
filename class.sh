#!/usr/bin/env bash

test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${us_stat:-exit} $?

uc_script_load user-script || ${us_stat:-exit} $?

! script_isrunning "class.sh" ||
  uc_script_load us-als-mpe || ${us_stat:-exit} $?

class_sh__grp=user-script-sh
class_sh__libs=lib-uc,context-uc,uc-class

class_sh_ () # ~ <Switch> ...
{
  local a1_def=summary; sa_switch_arg
  case "$switch" in

  ( e|eval ) # ~ ~ <script...> [ -- <script...> ]
      class_init XContext &&
      declare xctx ctxref=xctx &&
      class_new xctx XContext &&
      $xctx-e "$@"
    ;;

  ( [@+]* ) # ~ <Class-ref> [<call> <args...> [ -- <call> <args...> ]]
      ! sys_debug init || {
        user_script_load rulesenv || return
        CT_VERBOSE=true
        rule_run rule/begin "class.sh--$switch--${*// /_}" || return
      }

      # Create class from reference (with no constructor arguments, ie. using
      # only class-id), and treat arguments as a sequence of invocations on
      # that object.
      class_init XContext &&
      declare xctx ctxref=xctx &&
      class_new xctx XContext &&
      $xctx$switch &&
      #if_ok "$($xctx.class)/$($xctx.id)" || return
      context_cmd_seq xctx "$@"

      local stat=$?
      ! sys_debug init || {
        sys_stat $stat
        rule_run rule/end "class.sh--$switch--${*// /_}" || return
      }
      return $stat
    ;;

    * ) sa_E_nss
  esac
  __sa_switch_arg
}


class_sh_info ()
{
  local a1_def=--summary; sa_switch_arg
  case "$switch" in

  ( -list | -types )
      class_sh_info -load-from-libs "$@" &&
      [[ "${Class__type[*]:+set]}" ]] || {
        sys_debug quiet &&
          $LOG warn "" "No class types found" || return
      }
      echo "${!Class__type[@]}" | column
    ;;
  ( -load-from-libs )
      [[ $# -eq 0 ]] || {
        user_script_initlibs "$@" || return
      }
      class_init ${ctx_class_types:?} || return
    ;;
  ( -static | -static-types ) # ~ ~ <Sh-libs...>
      class_sh_info -load-from-libs "$@" &&
      [[ "${Class__static_type[*]:+set]}" ]] || {
        sys_debug quiet &&
          $LOG warn "" "No class types loaded" || return
      }
      echo "${!Class__static_type[@]}" | column
    ;;
  ( -list-all | -locate )
      locate -ibe '*.class.sh' | column
    ;;
  ( -summary ) # ~ ~ <Sh-libs...>
      if_ok "$(locate -ibe '*.class.sh' | count_lines)" &&
      stderr echo "Found $_ class.sh files"
      class_sh_info -load-from-libs "$@" &&
      : "${#Class__static_type[*]}"
      stderr echo "Found $_ loaded types"
      : "${#Class__type[*]}"
      stderr echo "Found $_ defined types"
    ;;

    * ) sa_E_nss
  esac
  __sa_switch_arg
}


## User-script parts

class_sh_maincmds=""
class_sh_shortdescr="Make calls to class instances"

class_sh_aliasargv ()
{
  test -n "${1:-}" || return ${_E_MA:?}
  case "${1//_/-}" in
  ( "-?"|-h|h|--help|help|user-script-help ) set -- user_script_help "${@:2}" ;;
  ( --usage|usage ) user_script_usage "${@:2}" ;;
  ( --list-all ) set -- info "$@" ;;
  ( info ) ;;
    * ) set -- class_sh_ "$@"
  esac
}

class_sh_loadenv ()
{
  user_script_loadenv &&
  user_script_initlog &&
  user_script_load scriptenv || return
  export v=${v:-4}
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
  script_defcmd=--summary
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
