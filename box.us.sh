#!/bin/sh

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

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
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


# Main entry (see user-script.sh for boilerplate)

test -n "${user_script_loaded:-}" || {
  set -e
  . "${US_BIN:="$HOME/bin"}"/user-script.sh &&
      user_script_shell_env &&
          . /srv/project-local/conf-wtwta/script/Generic/server.sh
}

! script_isrunning "box.us" .sh || {

  # Strip extension from scriptname (and baseid)
  script_baseext=.sh
  # Default value used if argv is empty
  script_defcmd=stat
  # To include all aliases for user_script_defarg
  script_fun_xtra_defarg=box_us_aliasargv\ server_sh_aliasargv
  # To extract aliases for help
  script_xtra_defarg=box_us_aliasargv\ server_sh_aliasargv

  # Resolve aliased commands or set default
  eval "set -- $(user_script_defarg "$@")"
}

script_entry "box.us" "$@"

#
