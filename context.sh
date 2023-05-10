#!/usr/bin/env bash


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

context_sh_status () # ~
{
  local act="${1:-short}"
  test $# -eq 0 || shift
  local lk=${lk:-:context}:status
  case "$act" in
    ( s|short )
            context_sh_files check
            $LOG info :context.sh:status "Files check" E$? E? || return
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

context_sh_aliasargv ()
{
  case "$1" in
      ( s|short ) shift; set -- context_sh_status short ;;
      ( f|files ) shift; set -- context_sh_files "$@" ;;
  esac
}

context_sh_loadenv ()
{
  shopt -s nullglob &&
  lib_load os-htd
}

context_sh_unload ()
{
  shopt -u nullglob
}


# Main entry (see user-script.sh for boilerplate)

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script

! script_isrunning "context.sh" || {
  user_script_load || exit $?
  # Default value used if argv is empty
  script_defcmd=short
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
