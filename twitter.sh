#!/usr/bin/env make.sh
# Twitter


#Script subcmd's funcs and vars

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

twitter_man_1__help="Usage help. "
twitter_spc__help="-h|help"
twitter_als___h=help
twitter__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
}




# Script main functions

MAKE-HERE
INIT_ENV="init-log 0 0-src 0-u_s dev ucache scriptpath std box" \
INIT_LIB="str sys os std shell log src match main stdio std meta box date doc table remote logger-theme"

main-epilogue
# Id: script-mpe/0.0.4-dev twitter.sh
