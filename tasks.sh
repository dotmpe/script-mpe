#!/usr/bin/env bash

test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${us_stat:-exit} $?

uc_script_load user-script || ${us_stat:-exit} $?

! script_isrunning "tasks" .sh ||
  uc_script_load us-als-mpe || ${us_stat:-exit} $?


tasks__libs=todotxt,basedir-htd
tasks__hooks=tasks_basedir_init,tasks_local_init

# instead of separate handlers for user-script commands, prefix preproc_ as
# default (see user-script aliasargv hook)
tasks_ ()
{
  local a1_def=summary; sa_switch_arg
  case "$switch" in

    ( all )
        declare ft file{version,id,mode}

        context_require Locate TodoTxt Status &&

        # @Locate.all.ignore-case.existing
        @Locate/Aie '*/todo.txt' | while read -r tf
        do
          fml_lvar=true filereader_modeline "$tf" ft=todo ft=todo.txt || {
            : "file:$tf"
            : "$_${fileid:+:id=$fileid}"
            : "$_${fileversion:+:ver=$fileversion}"
            : "$_${filemode:+:mode=$filemode}"
            $LOG info "" "Skipping" "$_"
            continue
          }
          # @TodoFile @Context @FileReader
          # @Status => sum TodoTxt.PRI
          #stderr echo File: $tf
          if_ok "$(todotxt_field_prios < "$tf" | count_lines)" &&
            echo "$tf priorities: $_" ||
            echo "$tf (priorities): [no data]"
        done
      ;;

    ( I|index ) TODO index $* ;;

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
        $todotxt.byPriority "0" ;;

    ( s|short|summary )
        stderr echo BaseDir $sym=$bd/ &&
        stderr $todotxt.class-tree &&
        stderr $todotxt.class-params &&
        TODO summary $* ;;

      * ) sa_E_nss
  esac
  __sa_switch_arg
}


## User-script parts

tasks_maincmds="all short status update-all"
tasks_shortdescr='Todo.txt ops'

tasks_aliasargv ()
{
  test -n "${1-}" || return
  case "${1//_/-}" in
    ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;
    ( * ) set -- tasks_ "$@" ;;
  esac
}

tasks_loadenv () # ~ <Cmd-argv...>
{
  user_script_loadenv &&
  user_script_initlog || return
  shopt -s nullglob nocaseglob
  #us_log_v_warn
  script_part=${base:?} user_script_load groups || {
    test ${_E_next:?} -eq $? || return $_
  }
  #script_part=${1:?} user_script_load groups && return
  #test ${_E_next:?} -eq $? || return $_
  $LOG notice :tasks.sh "No specific env for script or command" "$*"
  uc_log notice "$lk:loadenv" "User script loaded" "[-$-] (#$#) ~ ${*@Q}"
}

tasks_unload ()
{
  test -z "${todotxt-}" || destroy todotxt
  shopt -u nullglob nocaseglob
}

# Load hooks

tasks_basedir_init ()
{
  declare bd
  user_script_initlibs sys &&
  if_ok "$(cwd_lookup_paths)" &&
  for bd in $_
  do
    sym=$($basedirtab.key-by-index 1 "$bd/" 2) || continue
    break
  done &&
    stderr echo found basedir $sym=$bd/ ||
    $LOG warn "" "No basedir" "E$?:$PWD" $?
}

tasks_local_init ()
{
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
