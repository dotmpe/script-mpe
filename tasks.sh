#!/usr/bin/env bash

test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${us_stat:-exit} $?

uc_script_load user-script || ${us_stat:-exit} $?

! script_isrunning "tasks" .sh ||
  uc_script_load us-als-mpe || ${us_stat:-exit} $?


tasks__libs=todotxt,us-fun
tasks__hooks=us_basedir_init,tasks_local_init

tasks_uc__libs=stattab-class,class-uc

tasks_all__grp=uc
tasks_all__libs=tasks,meta-xattr
tasks_all__hooks=us_stbtab_init


# instead of separate handlers for user-script commands, prefix preproc_ as
# default (see user-script aliasargv hook)
tasks_ ()
{
  local a1_def=summary; sa_switch_arg
  case "$switch" in

  ( all-ng )
      user_script_initlibs context &&
      context_require Locate TodoTxt Status &&

      # @Locate/all,ignore-case,existing
      @Sh/data:tf \
      @Locate/Aie \
        '*/todo.txt' 'out_fmt=${out_fmt:-summary} tasks_scan_prio "$tf"'
    ;;

  ( all )
      script_part=all user_script_load groups || return
      : "${1:-files}"
      : "${_//-/}"
      declare out_fmt=$_ tfiles tf &&
      if_ok "$(locate -Aie '*/todo.txt')" &&
      mapfile -t tfiles <<< "$_" || return
      declare cnt=0 pass=0 errs=0
      for tf in "${tfiles[@]}"
      do
        stbctx=${stbtab:?} tasks_scan "$tf" || return
      done
      : $(( cnt + pass + errs ))
      : "Checked $_ files,"
      : "$_ $(( errs + pass )) files skipped ($errs non-task files),"
      : "$_ $cnt task files have priorities set"
      $LOG notice :tasks:all "$_"
    ;;

  ( C|check ) TODO check $*
    ;;

  ( count ) $todotxt.count-tasks ;;

  ( debug )
      #$todotxt.class-debug
      us_stbtab_init &&
      ${stbtab:?}.class-debug
    ;;

  ( I|index ) TODO index $*
    ;;

  ( info )
      us_stbtab_init &&
      stderr echo "StatTab table file: $(${stbtab:?}.tab-ref)"
      stderr echo "Tasks file: $(${todotxt:?}.attr file FileReader)"
    ;;

  ( l|ls|list )
      $todotxt.list-tasks
    ;;

  ( list-files )
      us_stbtab_init &&
      ${stbtab:?}.list
    ;;

  ( ml|modeline )
      test 0 -lt $# || {
        if_ok "$($todotxt.attr file FileReader)" || return
        set -- "$_"
      }
      declare file{version,id,mode}
      fml_lvar=true filereader_modeline "$1" ft=todo ft=todo.txt &&
      {
        : "file:${1-}"
        : "$_${fileid:+:id=$fileid}"
        : "$_${fileversion:+:ver=$fileversion}"
        : "$_${filemode:+:mode=$filemode}"
        $LOG notice "" "Found" "$_"
      }
    ;;

  ( S|status )
      $todotxt.priorities
      return
      $todotxt.byPriority "0"
    ;;

  ( s|short|summary )
      stderr echo BaseDir $sym=$bd/ &&
      stderr $todotxt.class-tree &&
      stderr $todotxt.class-params &&
      TODO summary $*
    ;;

    * ) sa_E_nss
  esac
  __sa_switch_arg
}


## User-script parts

tasks_maincmds="all short status update-all"
tasks_shortdescr='Todo.txt ops'

tasks_aliasargv ()
{
  test -n "${1:-}" || return ${_E_MA:?}
  case "${1//_/-}" in
  ( "-?"|-h|h|help|user-script-help ) shift; set -- user_script_help "$@" ;;
    * ) set -- tasks_ "$@"
  esac
}

tasks_loadenv () # ~ <Cmd-argv...>
{
  user_script_loadenv &&
  user_script_initlog || return
  #set -o pipefail
  shopt -s nocaseglob
  # XXX: nullglob influences user-script log-key handling...
  #shopt -s nullglob nocaseglob
  #us_log_v_warn
  script_part=${base:?} user_script_load groups || {
    # E:next means no libs found for given group(s).
    test ${_E_next:?} -eq $? || return $_
  }
  script_part=${1:?} user_script_load groups && return
  test ${_E_next:?} -eq $? || return $_
  $LOG notice :tasks.sh "No specific env for script or command" "$*"
  uc_log notice "$lk:loadenv" "User script loaded" "[-$-] (#$#) ~ ${*@Q}"
}

tasks_unload ()
{
  test -z "${todotxt-}" || destroy todotxt
  shopt -u nullglob nocaseglob
}

# Add. load hooks

tasks_local_init ()
{
  class_init TodoTxtFile TodoTxtTask || return
  declare tf
  for tf in [Tt][Oo][Dd][Oo].[Tt][Xx][Tt]
  do
    test -f "$tf" || continue
    create todotxt TodoTxtFile "$tf"
    return
  done
  return ${_E_not_found:?}
}

# Main entry (see user-script.sh for boilerplate)

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script

! script_isrunning "tasks" .sh || {
  export UC_LOG_BASE="${SCRIPTNAME}[$$]"
  user_script_load defarg || exit $?
  # Default value used if argv is empty
  script_defcmd=short
  user_script_defarg=defarg\ aliasargv
  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}

# Id: script-mpe/0.0.4-dev tasks.sh
