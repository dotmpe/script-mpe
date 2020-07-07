#!/usr/bin/env make.sh

version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

tasks__list()
{
  echo TODO: google, redmine, local target, todotxtmachine
}


tasks__update()
{
  req_vars HTDIR
  cp $HTDIR/to/do.list $HTDIR/to/do.list.ro
  cat $HTDIR/to/do.list.ro | while read id descr
  do
    case "$id" in
      [-*+] ) # list-item:
        ;;
      . ) # class?
        ;;
      "#" ) # id or comment.. srcid?
        ;;
    esac
    echo "$id"
  done
}


# Generic subcmd's

tasks_man_1__help="Usage help. "
tasks_spc__help="-h|help"
tasks__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
}
tasks_als___h=help
tasks_als____help=help


tasks_man_1__version="Version info"
tasks__version()
{
  echo "script-mpe:$scriptname/$version"
}
tasks_als___V=version
tasks_als____version=version


tasks__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
tasks_als___e=edit


# Script main functions

MAKE-HERE
INIT_ENV="init-log 0 0-src 0-u_s 0-1-lib-sys 0-std ucache scriptpath box"
INIT_LIB="os sys main str shell meta box date doc table remote tasks std stdio match log src src-htd"
main-local
failed= tasks_session_id
main-lib
  local __load_lib=1
  INIT_LOG=$LOG lib_init || return
main-unload
  clean_failed || unload_ret=1 ; unset failed
main-epilogue
# Id: script-mpe/0.0.4-dev tasks.sh
