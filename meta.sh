#!/usr/bin/env bash

## Bootstrap

test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${us_stat:-exit} $?

uc_script_load user-script

# Define aliases immediately, before function declarations and before entering
# main script_{entry,run}
! script_isrunning "meta.sh" ||
  uc_script_load us-als-mpe || ${us_stat:-exit} $?


meta_sh__grp=meta
meta_sh__hooks=us_userdir_init
meta__grp=status-uc
meta__libs=meta,us-fun
meta__hooks=us_xctx_init
#status__libs=status
#status__grp=user-script


meta_sh_attributes () # ~
{
  meta_attributes "${@:?}"
}
meta_sh_attributes__grp=meta-sh


meta_sh_check () # ~ \!TODO
{
  local a1_def=summary; sa_switch_arg
  case "$switch" in

  ( summary )
        stderr echo SD-Local: ${SD_LOCAL:?}
        sym=$($xctx.attr basedir-symbol User_Dir) &&
        bd=$($xctx.attr path Dir) &&
        stderr echo "$sym: $bd/"

        $LOG warn : TODO check 1
      ;;

    * ) sa_E_nss

  esac
  __sa_switch_arg
}


meta_sh_context () # ~ [ <Paths...> ] # List attributes at paths and parents
{
  test $# -gt 0 ||
      eval "set -- ${meta_sh_default_leafs:-"\{.,\{main,index,default}.*}"}"
  : "${@:?meta.sh:context: Paths argument expected}"
  $LOG notice "" "Listing attributes" "$#:$*"
  declare -A metapaths

  local attr path
  while test 0 -lt $#
  do
    path=$(realpath -s "${1:?}") &&
    attr=$(meta_attributes "$path") || return
    test -z "$attr" ||
        metapaths[$path]=$attr
    while test "$path" != /
    do
      path=$(dirname "$path")
      test -n "${metapaths[$path]-unset}" || continue
      attr=$(meta_attributes "$path") || true
      metapaths[$path]=$attr
    done
    shift
  done

  for path in $(foreach "${!metapaths[@]}" | sort )
  do
    attr="${metapaths[$path]:-}"
    test -n "$attr" || continue
    echo "$path:"
    echo "$attr" | sed 's/^/  /'
  done
}
meta_sh_context__grp=meta-sh


meta_sh_local () # ~ <Action> #  XXX: local
{
  local sa_lk=:local a1_def=basedir; sa_switch_arg
  case "$switch" in

  ( basedir )
      sym=$($xctx.attr basedir-symbol User_Dir) &&
      bd=$($xctx.attr path Dir) &&
      #bd=${!sym} || return
      echo $sym=$bd/
    ;;

    * ) sa_E_nss
  esac
  __sa_switch_arg
}


## User-script parts

#meta_sh_name=foo
#meta_sh_version=xxx
meta_sh_maincmds="attributes context help short version"
meta_sh_shortdescr='Track metadata'

meta_sh_aliasargv ()
{
  test -n "${1-}" || return
  case "${1//_/-}" in
  ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;
  # * ) set -- meta_sh_ "$@"
  esac
}

meta_sh_loadenv ()
{
  user_script_loadenv &&
  user_script_initlog || return
  shopt -s nullglob nocaseglob
  script_part=${base:?} user_script_load groups || {
    # E:next means no libs found for given group(s).
    test ${_E_next:?} -eq $? || return $_
  }
  #script_part=${1:?} user_script_load groups && return
  #test ${_E_next:?} -eq $? || return $_
  #$LOG notice :meta.sh "No specific env for script or command" "$*"
  user_script_announce "$@"
}

meta_sh_unload ()
{
  shopt -u nullglob nocaseglob
}

# Main entry (see user-script.sh for boilerplate)

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script

! script_isrunning "meta.sh" || {
  export UC_LOG_BASE="${SCRIPTNAME}[$$]"
  user_script_load || exit $?

  # Pre-parse arguments
  script_defcmd=check
  #user_script_defarg=defarg\ aliasargv
  eval "set -- $(user_script_defarg "$@")"

  script_run "$@"
}
