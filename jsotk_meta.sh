#!/bin/sh
set -e

. ~/bin/util.sh
lib_load
jsotk_sock=/tmp/jsotk-serv.sock

fnmatch "$1" "-*" || {
  test -x "$(which socat)" -a -e "$jsotk_sock" && {

    main_sock=$jsotk_sock main_bg_writeread "$@"
    exit $?
  }
}
exit 1
#test -n "$pd_sock" && set -- --address $pd_sock "$@"
#$scriptpath/jsotk-serve -f $pdoc "$@" || return $?
