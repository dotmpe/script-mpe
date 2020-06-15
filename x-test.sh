#!/usr/bin/env bash
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

test___h()
{
  test__help
}
test__help()
{
  echo Help?
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

        . $scriptpath/tools/sh/init.sh || return
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




# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  test "$1" != load-ext || __load_lib=1
  test -n "${__load_lib-}" || {
    test_main "$@"
  }
;; esac

# Id: script-mpe/0.0.4-dev x-test.sh
