#!/usr/bin/env bash

test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${stat:-exit} $?
uc_script_load user-script || ${stat:-exit} $?

# Use alsdefs set to cut down on small multiline boilerplate bits.
#user_script_alsdefs
! script_isrunning "match" .sh ||
  ALIASES=1 user_script_shell_mode || ${stat:-exit} $?


### Match:


## Main command handlers

names ()
{
  local _1def='list-local' n='names'; sa_a1_d_nlk
  : "${MATCH_NAMETAB:=${METADIR:?}/tab/names.list}"
  case "$1" in
    ( list-global )
        TODO
      ;;
    ( list-local )
        test -e "$MATCH_NAMETAB" ||
            $LOG error "$lk" "No local table exists" "$_" ${_E_NF:?} || return
        cut -d' ' -f3,2 < "$_"
      ;;
    ( list )
        TODO
      ;;

    ( * ) sa_E_nschc ;;
  esac
  return $?

  #test $# -gt 0 && {
  #  create ctx NameAttrs

  test -e "$_" ||
      $LOG error "$lk:names" "No names table" $_ ${_E_not_found}
  #test -e "$_" || return
  #create ctx NameAttrs "$MATCH_NAMETAB"
  #$ctx.names
  cat $MATCH_NAMETAB
  exit $?

  echo status-dirs: ${status_dirs:?}
  status_dirs
  out_fmt=list cwd_lookup_path ${status_dirs:?}
}
names__libs=meta\ match-htd\ ctx-class\ sys\ status

var_names ()
{
  TODO
}


## User-script parts

match_maincmds="names var-names"
match_shortdescr='Split and assemble file names and strings from patterns'

match_aliasargv ()
{
  test -n "${1:-}" || return
  case "${1//_/-}" in

    ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;
  esac
}

match_loadenv () # ~ <Cmd-argv...>
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

! script_isrunning "match" .sh || {
  export UC_LOG_BASE="$SCRIPTNAME.sh[$$]"
  user_script_load || exit $?
  script_defcmd=check
  user_script_defarg=defarg\ aliasargv
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
