#!/bin/sh

twitter_src=$_
test -z "$__load_lib" || set -- "load-ext"

set -e



twitter__meta()
{
  twitter-meta.py "$@"
}


twitter__list()
{
  twitter__meta verify-creds | pretty_object
}

twitter__lists()
{
  test -n "$1" || set -- list
  case "$1" in
    create )
        shift
        test -n "$1" || error "Name expected"
        twitter__meta create-list "$@"
      ;;
    destroy )
        shift
        test -n "$1" || error "Name expected"
        twitter__meta destroy-list "$@"
      ;;
    update ) ;;
    list )
        {
          echo "# ID	NAME	MODE	MMBR_CNT	SUB_CNT"
          twitter__meta lists
        } | column -tc 5 -s "$(printf "\t")"
      ;;
  esac
}


pretty_object()
{
  jsotk.py json2yaml --pretty -
}


### Main


twitter_main()
{
  local scriptname=twitter base=$(basename $0 .sh) verbosity=5 \
    scriptdir="$(cd "$(dirname "$0")"; pwd -P)" \
    failed=

  twitter_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        twitter_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

twitter_init()
{
  test -n "$scriptdir"
  export SCRIPTPATH=$scriptdir
  . $scriptdir/util.sh
  util_init
  . $scriptdir/match.lib.sh
  . $scriptdir/box.init.sh
  box_run_sh_test
  #. $scriptdir/htd.lib.sh
  . $scriptdir/main.lib.sh load-ext
  . $scriptdir/meta.lib.sh
  . $scriptdir/box.lib.sh
  . $scriptdir/date.lib.sh
  . $scriptdir/doc.lib.sh
  . $scriptdir/table.lib.sh
  lib_load remote
  # -- twitter box init sentinel --
}

twitter_lib()
{
  local __load_lib=1
  . $scriptdir/match.sh load-ext
  # -- twitter box lib sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
    twitter_main "$@"
  ;; esac
;; esac

# Id: script-mpe/0.0.3-dev twitter.sh
