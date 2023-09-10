#!/bin/bash

set -e


scr_test_bash_main_load()
{
  lib_loading=1
  . $scriptpath/main.lib.sh load-ext
  . $scriptpath/util.sh load-ext
}

scr_test_bash_main()
{
  test -n "$scriptpath" || scriptpath="$(dirname "$(dirname $0)")"
  scr_test_bash_main_load
  test -n "$1" || error arg 13
  util_init
  case "$1" in
    load-ext )
      ;;
    var-isset )
        sh_isset "$2" || exit $?
      ;;
    * )
        error "Missing/unknown '$1'." 12
      ;;
  esac
}

scr_test_bash_main "$@"
