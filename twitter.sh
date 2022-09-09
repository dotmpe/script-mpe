#!/usr/bin/env make.sh
# Twitter

set -eu


twitter__meta()
{
  twitter-meta.py "$@"
}


twitter__list()
{
  twitter__meta verify-creds |
      jsotk.py json2yaml --pretty -
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



# Generic subcmd's

twitter_als____version=version
twitter_als___V=version
twitter_grp__version=ctx-main\ ctx-std

twitter_als____help=help
twitter_als___h=help
twitter_grp__help=ctx-main\ ctx-std


# Script main functions

#std log src match main stdio meta box date doc table remote logger-theme"
MAKE-HERE
INIT_ENV="init-log 0 0-src 0-u_s dev ucache scriptpath std box" \
INIT_LIB="\\$default_lib"

main-epilogue
# Id: script-mpe/0.0.4-dev twitter.sh
