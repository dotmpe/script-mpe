#!/usr/bin/env bash

### A new box.sh based on @User_script.lib+dev

#version=0.0.4-dev # script-mpe


rulesets () # ~
{
  test $# -gt 0 || set -- run 1
  local lk=${lk:-}:rule-sets
  case "${1:?}" in

  ( l|list ) # ~ [<Level>] [<Header> <Glob>] [<Cmd-Regex>] [<Format>]
        shift
        test $# -gt 0 || set -- '*'
        rules_list user/diag "$@" ;;

  ( * ) $LOG error "$lk" "No such action" "$1" ${_E_nsa:-68}
  esac
}


## User-script parts

box_us_maincmds="diagnostics help rulesets status update version"
box_us_shortdescr='Generic user shell tool.'

box_us_aliasargv ()
{
  case "$1" in
    ( l|list) shift; set -- rulesets list "$@" ;;
    ( rs|rulesets ) shift; set -- rulesets "$@" ;;

    ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;
  esac
}

box_us_loadenv ()
{
  server_sh_loadenv
}

box_us_bases ()
{
  user_script_bases >/dev/null
  script_bases="${script_bases:?} server_sh"
  echo "$script_bases"
}


box_us_loadenv ()
{
  . /srv/project-local/conf-wtwta/script/Generic/server.sh
}

# Main entry (see user-script.sh for boilerplate)

us-env -r user-script || ${uc_stat:-exit} $?

! script_isrunning "box.us" .sh || {
  user_script_load || exit $?

  # Strip extension from scriptname (and baseid)
  script_baseext=.sh
  # Default value used if argv is empty
  script_defcmd=stat
  # To extract aliases for help
  user_script_defarg=defarg\ aliasargv
  user_script_bases=box_us_bases

  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"

  script_run "$@"
}

#
