#!/usr/bin/env bash

## Bootstrap

us-env -r user-script || ${uc_stat:-exit} $?

# Define aliases immediately, before function declarations and before entering
# main script_{entry,run}
! script_isrunning "preproc" .sh ||
  uc_script_load us-als-mpe || ${us_stat:-exit} $?


preproc_ () # ~ <File> #
{
  local a1_def=summary; sa_switch_arg
  case "$switch" in

  ( enum )  preproc_includes_enum "$@" ;;

  ( files ) preproc_includes "$@" ;;

  ( list )  preproc_includes_list "$@" ;;

  ( run )
            preproc_run "$@"
      ;;

  ( runner )
            src_reader_ "$@" &&
            preproc_runner
      ;;

    * ) sa_E_nss

  esac
  __sa_switch_arg
}
preproc__grp=preproc-us


## User-script parts

preproc_name="preproc+us"
preproc_version=0.0.1-dev
preproc_maincmds=foo
preproc_shortdescr="Pre-processing"
preproc_extusage=

preproc_us__grp=user-script
preproc_us__libs=lib-uc,filereader-htd,preproc

preproc_aliasargv ()
{
  test -n "${1-}" || return
  case "${1//[_-]}" in
    ( "?"|h|help ) shift; set -- user_script_help "$@" ;;
    ( enum ) shift; set -- preproc_ -enum "$@" ;;
    ( files ) shift; set -- preproc_ -files "$@" ;;
    ( list ) shift; set -- preproc_ -list "$@" ;;
    ( run ) shift; set -- preproc_ -run "$@" ;;
    ( runner ) shift; set -- preproc_ -runner "$@" ;;
  esac
}

preproc_loadenv () # ~ <Cmd-argv...>
{
  shopt -s nullglob nocaseglob
}

preproc_unload ()
{
  shopt -u nullglob nocaseglob
}

# Main entry (see user-script.sh for boilerplate)

! script_isrunning "preproc" || {
  # Load script specific, and modify arguments
  user_script_load || exit $?
  script_defcmd=list
  user_script_defarg=defarg\ aliasargv
  eval "set -- $(user_script_defarg "$@")"
}

# Execute argv and return
script_entry "preproc" "$@"
#
