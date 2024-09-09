#!/usr/bin/env bash

us-env -r us:boot.screnv &&

us-env -r user-script || ${uc_stat:-exit} $?

# Use alsdefs set to cut down on small multiline boilerplate bits.
#user_script_alsdefs
#! script_isrunning "list.sh" ||
#  ALIASES=1 user_script_shell_mode || ${stat:-exit} $?


### List: manage and utilize globlist files

list_sh__grp=list
list__grp=user-script

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

list_sh_name=List.sh
list_sh_version=0.0.0-alpha
list_sh_maincmds="files globs"
list_sh_shortdescr='Manage and use globlists'
#list_sh_defcmd=

list_sh_aliasargv ()
{
  [[ ${1-} ]] || return ${_E_MA:?}
  case "$1" in
  ( attrs ) shift; set -- attributes "$@" ;;
  ( group ) shift; set -- files -groups "$@" ;;
  esac
}

list_sh_loadenv () # ~ <Cmd-argv...>
{
  ignores_use_local_config_dirs=false
  #ignores_prefix=local
  ignores_prefix=htd
  globlist_prefix=htd
  lib_load list &&
  return ${_E_continue:?}
}

# Main entry (see user-script.sh for boilerplate)

! script_isrunning "list.sh" || {
  user_script_load || exit $?
  user_script_defarg=defarg\ aliasargv
  if_ok "$(user_script_defarg "$@")" &&
  eval "set -- $_" &&
  script_run "$@"
}
