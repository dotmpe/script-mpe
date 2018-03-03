#!/bin/sh
test_src="$_"

set -e


version=0.0.4-dev # script-mpe


test__version()
{
  echo $version
}
test___V() { test__version; }
test____version() { test__version; }


test__ack()
{
  echo Ack.
}



test_main()
{
  # Do something if script invoked as 'x-test.sh'
  local scriptname=x-test base="$(basename "$0" .sh)" \
    subcmd=$1

  case "$base" in $scriptname )

        test -n "$scriptpath" || \
            scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
            pwd=$(pwd -P) ppwd=$(pwd) spwd=.

        export SCRIPTPATH=$scriptpath
        . $scriptpath/util.sh load-ext

        test -n "$verbosity" || verbosity=5

        local func=$(echo test__$subcmd | tr '-' '_') \
            failed= \
            ext_sh_sub=

        lib_load str match main std stdio sys os src

        type $func >/dev/null 2>&1 && {
          shift 1
          $func "$@" || return $?
        } || {
          R=$?
          test $R -eq 127 && warn "No such command '$1'"
          return $R
        }
      ;;

    * )
        echo "Test is not a frontend for $base ($scriptname)" 2>&1
        exit 1
      ;;

  esac
}




# Ignore login console interpreter
case "$0" in "" ) ;; "-"* ) ;; * )
  test -n "$f_lib_load" || {
    __load_mode=main . ~/bin/util.sh
    test "$1" = "$__load_mode" ||
      set -- "$__load_mode" "$@"

    case "$1" in
      main ) shift ; test_main "$@" ;;
    esac

  } ;;
esac
