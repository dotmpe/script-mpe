#!/bin/sh

tasks_src=$_
test -z "$__load_lib" || set -- "load-ext"

set -e



tasks__list()
{
  echo TODO: google, redmine, local target, todotxtmachine
}



### Main


tasks_main()
{
  local scriptname=tasks base=$(basename $0 .sh) verbosity=5 \
    scriptdir="$(cd "$(dirname "$0")"; pwd -P)" \
    failed=

  tasks_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        tasks_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

tasks_init()
{
  # XXX test -n "$SCRIPTPATH" , does $0 in init.sh alway work?
  test -n "$scriptdir"
  export SCRIPTPATH=$scriptdir
  . $scriptdir/util.sh
  util_init
  . $scriptdir/match.lib.sh
  . $scriptdir/box.init.sh
  box_run_sh_test
  #. $scriptdir/htd.lib.sh
  lib_load main meta box data doc table remote
  # -- tasks box init sentinel --
}

tasks_lib()
{
  local __load_lib=1
  . $scriptdir/match.sh load-ext
  # -- tasks box lib sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
    tasks_main "$@"
  ;; esac
;; esac

