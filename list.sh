#!/usr/bin/env bash

test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${stat:-exit} $?
uc_script_load user-script || ${stat:-exit} $?

# Use alsdefs set to cut down on small multiline boilerplate bits.
#user_script_alsdefs
#! script_isrunning "list.sh" ||
#  ALIASES=1 user_script_shell_mode || ${stat:-exit} $?


### List: manage and utilize globlist files

# Primary use is to filter file names,

list_sh_xctx__libs=attributes,std-uc,class-uc,us-fun
list_sh_xctx__hooks=us_xctx_init

## Main command handlers

list_sh_attributes__grp=xctx
list_sh_attributes () # ~
{
  local lk uref
  us_xctx_switch @List/Name "$@" || return
  test -z "${uref:-}" || shift
  lk=${lk:-:list}:attributes${1:+:}${1:- -summary}
  $xctx:attributes${1:--summary} "${@:2}"
}

list_sh_files__grp=xctx
list_sh_files () # ~ <Act> <Groups...>
{
  local lk uref
  us_xctx_switch @List/Name "$@" || return
  test -z "${uref:-}" || shift
  lk=${lk:-:list}:files${1:+:}${1:- -find}
  $xctx:files${1:--find} "$@"
}

list_sh_globs__grp=xctx
list_sh_globs () # ~ <Groups...> # List all globs from group
{
  local lk uref
  us_xctx_switch @List/Glob "$@" || return
  test -z "${uref:-}" || shift
  lk=${lk:-:list}:globs${1:+:}${1:- -list}
  $xctx:globs${1:--list} "$@"
}

# Given group names, list the paths to the globlist source or cache files.
list_sh_names__grp=xctx
list_sh_names () # ~ [@Context] <Groups...> # List paths for globlists in group
{
  local lk=${lk:-:list}:names${1:+:}${1:-} ctx uref ctxclass
  us_xctx_switch @List/Name "$@" || return
  test -n "${uref-}" || shift
  lk=${lk:-:list}:names${1:+:}${1:- all}
  $xctx:names ${1:-all} "$@"
}




## User-script parts

list_sh_maincmds="files globs"
list_sh_shortdescr='Manage and use globlists'

list_sh_aliasargv ()
{
  test -n "${1:-}" || return
  case "${1//_/-}" in
    ( attrs ) shift; set -- attributes "$@" ;;
    ( group ) shift; set -- list_sh_files -groups "$@" ;;
    ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;
  esac
}

list_sh_loadenv () # ~ <Cmd-argv...>
{
  user_script_loadenv || return
  ignores_use_local_config_dirs=false
  #ignores_prefix=local
  ignores_prefix=htd
  globlist_prefix=htd
  script_part=${1:?} user_script_load groups || {
      # E:next means no libs found for given group(s).
      test ${_E_next:?} -eq $? || return $_
    }
  lib_load list script-mpe &&
  lib_init list script-mpe || return
  lk="$UC_LOG_BASE"
  $LOG notice "$lk:loadenv" "User script loaded" "[-$-] (#$#) ~ ${*@Q}"
}

# Main entry (see user-script.sh for boilerplate)

! script_isrunning "list.sh" || {
  export UC_LOG_BASE="${SCRIPTNAME}[$$]"
  user_script_load || exit $?
  user_script_defarg=defarg\ aliasargv
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
