#!/bin/sh

twitter_src=$_
test -z "$__load_lib" || set -- "load-ext"

set -e





# Script subcmd's funcs and vars

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



# Generic subcmd's

twitter_man_1__help="Usage help. "
twitter_spc__help="-h|help"
twitter_als___h=help
twitter__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
}




# Script main functions

twitter_main()
{
  local \
      scriptname=twitter \
      base=$(basename $0 .sh) \
      verbosity=5 \
      scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
      failed=

  twitter_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        twitter_lib || exit $?
        main_run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

# FIXME: Pre-bootstrap init
twitter_init()
{
  test -n "$scriptpath"
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh
  util_init
  . $scriptpath/match.lib.sh
  . $scriptpath/tools/sh/box.env.sh
  box_run_sh_test
  #. $scriptpath/htd.lib.sh
  . $scriptpath/main.lib.sh load-ext
  . $scriptpath/meta.lib.sh
  . $scriptpath/box.lib.sh
  . $scriptpath/date.lib.sh
  . $scriptpath/doc.lib.sh
  . $scriptpath/table.lib.sh
  lib_load remote
  # -- twitter box init sentinel --
}

# FIXME: 2nd boostrap init
twitter_lib()
{
  local __load_lib=1
  . $scriptpath/match.sh load-ext
  # -- twitter box lib sentinel --
  set --
}


# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
      twitter_main "$@"
    ;;
  esac ;;
esac

# Id: script-mpe/0.0.4-dev twitter.sh
