#!/usr/bin/env bash

test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${stat:-exit} $?
uc_script_load user-script || ${stat:-exit} $?

# Use alsdefs set to cut down on small multiline boilerplate bits.
#user_script_alsdefs
#! script_isrunning "list" .sh ||
#  ALIASES=1 user_script_shell_mode || ${stat:-exit} $?


### List: manage and utilize globlist files

# Primary use is to filter file names,


## Main command handlers

list_attr__libs=attributes
list_attr ()
{
  local lk=${lk:-:list}:files${1:+:}${1:-} ctx ctxref
  #list_contextload "$@" || return
  #user_script_initlibs attributes
  #test -z "${ctxref:-}" || shift

  ctx=attributes
  stderr echo 1.
  ${ctx}_stddef
  stderr echo 2.
  ${ctx}_pathspecs local global
  stderr echo
  stderr echo "3. paths 'local'"
  user_settings_paths local
  stderr echo
  stderr echo "4. paths 'global'"
  user_settings_paths global
}

list_files__libs=ignores
list_files () # ~ <Act> <Groups...>
{
  local lk=${lk:-:list}:files${1:+:}${1:-} ctx ctxref
  list_contextload "$@" || return
  test -z "${ctxref:-}" || shift
  case "${1-relative}" in

    ( find ) shift
        find_arg="-o -type f -a -print" ${ctx}_find_files "$@"
      ;;
    ( find-expr ) shift
        ${ctx}_find_expr "$@"
      ;;
    ( globlists ) shift
        ${ctx}_paths "$@" | filter_lines test -f
      ;;
    ( relative ) TODO
      ;;

    ( * ) return ${_E_nsk?} ;;
  esac
}

list_globs__libs=ignores
list_globs () # ~ <Groups...> # List all globs from group
{
  local lk=${lk:-:list}:globs${1:+:}${1:-} ctx ctxref
  list_contextload "$@" || return
  test -z "${ctxref:-}" || shift
  case "${1:-list}" in
    ( l|list ) shift;
        ${ctx}_raw "$@" | remove_dupes_nix ;;
    ( r|raw ) shift;
        ${ctx}_raw "$@" ;;

    ( * ) return ${_E_nsk?} ;;
  esac
  return

  test $# -eq 0 || set -- $(printf '%s\n' "$@" | sort -u)
  test $# -gt 0 || set -- $IGNORE_GROUPS
  {
    ${choice_nocache:-false} && {
      ignores_raw "$@" | remove_dupes_nix
      return
    } || {
      ignores_cache "$@" ||
        $LOG error : "Updating cache" "E$?:$*" $? || return
      if_ok "$(ignores_cache_file "$@")" &&
      test -f "$_" &&
      cat "$_" ||
        $LOG error : "Reading from cache file" "E$?:$*:$_" $? || return
      return $?
    }
  } | { ! ${choice_raw:-false} && {
      grep -Ev '^\s*(#.*|\s*)$' || return
    } || {
      cat - || return
    }
  }
  # XXX: cleanup old list-oldmk setup
  #lst_init_ignores "$ext" local global
  #echo read_nix_style_file $IGNORE_GLOBFILE$ext
}

# Given group names, list the paths to the globlist source or cache files.
list_names () # ~ [@Context] <Groups...> # List paths for globlists in group
{
  local lk=${lk:-:list}:names${1:+:}${1:-} ctx ctxref
  list_contextload "$@" || return
  test -z "${ctxref:-}" || shift
  case "${1:-}" in
    ( all ) shift; local glk gk
        glk="$(${ctx}_globlistkey)[*]" &&
        gk="$(${ctx}_groupkey)[*]" || return
        $LOG info "$lk" "Listing group- and list-names" "groups=$gk:globlists=$glk"
        echo ${!gk} ${!glk}
      ;;
    ( cache ) shift;
        ${ctx}_cachefile ;;
    ( groups ) shift; local gk
        gk="$(${ctx}_groupkey)[*]" || return
        $LOG info "$lk" "Listing groupnames" "groups=$gk"
        echo ${!gk} ;;
    ( globlists ) shift
        ${ctx}_paths "$@"
      ;;
    ( specs ) shift; local glk
        glk="$(${ctx}_globlistkey)[*]" || return
        $LOG info "$lk" "Listing listnames" "globlists=$glk"
        echo ${!glk} ;;
    ( * ) return 67 ;;
  esac
}
list_names__libs=globlist,ignores


## Util

list_contextload ()
{
  # Use tagref to init context
  fnmatch "@*" "${1:-}" && {
    ctxref=${1:?}
    shift
    fnmatch "[A-Z]*" "${ctxref:1}" && {
      user_script_initlibs ctx-class "ctx-${_,,}" &&
      create local:ctx "${ctxref:1}" || return
    } || ctx=$_
  } || ctx=globlist
  test -n "${ctxref:-}" || user_script_initlibs $ctx || return
  #local at_GlobList=
  #${ctx}_loaddefs &&
  #${ctx}_stddef || return
  $LOG notice : "Context ready" "$ctx"
}


## User-script parts

list_maincmds="files globs"
list_shortdescr='Manage and use globlists'

list_aliasargv ()
{
  test -n "${1:-}" || return
  case "${1//_/-}" in
    ( group ) shift; set -- list_files groups "$@" ;;
    ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;
  esac
}

list_loadenv () # ~ <Cmd-argv...>
{
  #user_script_loadenv || return
  : "${_E_not_found:=127}"
  : "${_E_next:=196}"
  ignores_use_local_config_dirs=false
  #ignores_prefix=local
  ignores_prefix=htd
  globlist_prefix=htd
  script_part=${1:?} user_script_load groups || {
      # E:next means no libs found for given group(s).
      test ${_E_next:?} -eq $? || return $_
    }
  lib_load "${base}" script-mpe &&
  lib_init "${base}" script-mpe || return
  lk="$UC_LOG_BASE"
  $LOG notice "$lk:loadenv" "User script loaded" "[-$-] (#$#) ~ ${*@Q}"
}

# Main entry (see user-script.sh for boilerplate)

! script_isrunning "list" .sh || {
  export UC_LOG_BASE="$SCRIPTNAME.sh[$$]"
  user_script_load || exit $?
  user_script_defarg=defarg\ aliasargv
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
