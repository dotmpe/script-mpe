#!/usr/bin/env bash

us-env -r user-script || ${uc_stat:-exit} $?

! script_isrunning "class.sh" ||
  uc_script_load us-als-mpe || ${uc_stat:-exit} $?

class__grp=user-script
class_sh__grp=class
#class__grp=
#script_base=class-sh,user-script-sh
#class_sh__grp=user-script-sh
class_sh_main__grp=class-sh
class_sh_main__libs=lib-uc,context-uc,uc-class

class_sh_main () # ~ <Switch> ...
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
  ( --list|--list-all|--static|--summary|--types )
    set -- info "$@" ;;
  ( info ) ;;
  #  * ) set -- main "$@"
  esac
}

class_sh_loadenv ()
{
  user_script_load scriptenv &&
  shopt -s nullglob nocaseglob
}

class_sh_unload ()
{
  shopt -u nullglob nocaseglob
}

# Main entry (see user-script.sh for boilerplate)

! script_isrunning "class.sh" || {
  script_base=class-sh,user-script-sh
  user_script_load || exit $?
  # Default value used if argv is empty
  # FIXME:
  script_defcmd=info\ --summary
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  if_ok "$(user_script_defarg "$@")" &&
  eval "set -- $_" &&
  script_run "$@"
}
