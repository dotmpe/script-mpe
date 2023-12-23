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

tasks_als____version=version
tasks_als___V=version
tasks_grp__version=ctx-main\ ctx-std

tasks_als____help=help
tasks_als___h=help
tasks_grp__help=ctx-main\ ctx-std

tasks__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
tasks_als___e=edit


## Main parts

MAKE-HERE
INIT_ENV="init-log 0 0-src 0-u_s 0-1-lib-sys 0-std ucache scriptpath box"
INIT_LIB="os sys main str shell meta box date doc table remote tasks std stdio match log src src-htd"
main-local
failed= dry_run= tasks_session_id
main-unload
  clean_failed || unload_ret=1 ; unset failed
main-epilogue
# Id: script-mpe/0.0.4-dev tasks-old.sh
