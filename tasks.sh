#!/bin/sh
tasks_src=$_

set -e



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

tasks_main()
{
  local
      scriptname=tasks \
      base=$(basename $0 .sh) \
      verbosity=5 \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
    failed=

  tasks_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        tasks_lib || exit $?
        main_run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

# FIXME: Pre-bootstrap init
tasks_init()
{
  # XXX test -n "$SCRIPTPATH" , does $0 in init.sh alway work?
  test -n "$scriptpath"
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh load-ext
  util_init
  . $scriptpath/match.lib.sh
  . $scriptpath/tools/sh/box.env.sh
  box_run_sh_test
  #. $scriptpath/htd.lib.sh
  lib_load main meta box date doc table remote tasks
  # -- tasks box init sentinel --
}

# FIXME: 2nd boostrap init
tasks_lib()
{
  local __load_lib=1
  . $scriptpath/match.sh load-ext
  # -- tasks box lib sentinel --
  set --
}


### Subcmd init, deinit

# Pre-exec: post subcmd-boostrap init
tasks_load()
{
  # -- tasks box lib sentinel --
  set --
}

# Post-exec: subcmd and script deinit
tasks_unload()
{
  local unload_ret=0

  for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  do case "$x" in
      f )
          clean_failed || unload_ret=1
        ;;
  esac; done

  unset subcmd subcmd_pref \
          tasks_default def_subcmd func_exists func \
          failed tasks_session_id

  return $unload_ret
}



# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  test "$1" != load-ext || __load_lib=1
  test -n "$__load_lib" || {
    tasks_main "$@" || exit $?
  }
;; esac

# Id: script-mpe/0.0.4-dev tasks.sh
