#!/usr/bin/env bash


context__grp=user-script
context_sh__grp=context

context_sh_files () # ~ <Action>
{
  local act="${1:-list}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:files:$act
  case "$act" in
    ( a|all )
          files_existing ".meta/stat/index/{context,ctx}{,-*}.list"
        ;;
    ( l|ls|list )
        context_sh_files c
        # Look for files and return non-zero if none found
        find .meta/stat/index -iname 'ctx-*.list' | grep . ;;
    ( c|check )
        # TODO: use statusdir or other to go over unique names
        test ! -e .meta/stat/index/context.list ||
            $LOG warn "$lk" "Should not have context.list" ;;
    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}
context_sh_files__libs=os-htd

context_sh_path ()
{
  local act="${1:-short}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:path
  case "$act" in
    ( s|short )
        out_fmt=list cwd_lookup_path .
      ;;
    ( * ) $LOG error "$lk" "No such action" "$1" 127 ;;
  esac
}
context_sh_path__libs=sys

context_sh_shell ()
{
  local act="${1:-short}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:shell

  user_script_ bases
  echo shell foo
  exit $?

  lib_load user-script-htd || return
  case "$act" in
    ( user-scripts )
        scripts=$(user_script_list_scripts | user_script_filter_userdirs)
        wc -l <<< "$scripts"
      ;;
    ( executable-scripts )
        scripts=$(user_script_list_scripts)
        wc -l <<< "$scripts"
      ;;
    ( count-shell-lib-lines )
        locate -b '*.lib.sh' |
                user_script_unique_names_count_script_lines
      ;;
    ( count-shell-script-lines )
        {
            user_script_list_scripts &&
            locate -b '*.sh'
        } | user_script_filter_userdirs |
                user_script_unique_names_count_script_lines
      ;;
    ( s|short )
      ;;
    ( * ) $LOG error "$lk" "No such action" "$1" 127 ;;
  esac
}
context_sh_shell__libs=user-script-htd

context_sh_status () # ~
{
  local act="${1:-short}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:status
  case "$act" in
    ( s|short )
            script_part=files user_script_load groups &&
            context_sh_files check
            $LOG info "$lk" "Files check" E$? $? || return
            wc -l $(context_sh_files a)
        ;;
    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}


## User-script parts

#context_sh_name=foo
#context_sh_version=xxx
context_sh_maincmds="help short version"
context_sh_shortdescr='Provide context entities and relations based on tags'

# Not using shell aliases in this script because they are a pain. But I wonder
# if they could make below setup a bit nicer.

context_sh_aliasargv ()
{
  case "$1" in
      ( s|short ) shift; set -- context_sh_status short ;;
      ( f|files ) shift; set -- context_sh_files "$@" ;;
  esac
}

context_sh_loadenv ()
{
  user_script_loadenv || return
  shopt -s nullglob || return
  user_script_baseless=true \
  script_part=${1:?} user_script_load groups || {
      # E:next means no libs found for given group(s).
      test ${_E_next:?} -eq $? || return $_
    }
  # Fallback if no group/libs defined for given cmd-name is to load base lib
  user_script_initlibs "${base//.*}" || return
  lk="$UC_LOG_BASE" &&
  $LOG notice "$lk:loadenv" "User script loaded" "[-$-] (#$#) ~ ${*@Q}"
}

context_sh_unload ()
{
  shopt -u nullglob
}


# Main entry (see user-script.sh for boilerplate)

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script

! script_isrunning "context.sh" || {
  export UC_LOG_BASE="${SCRIPTNAME}[$$]"
  user_script_load defarg || exit $?
  # Default value used if argv is empty
  script_defcmd=short
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
