#!/usr/bin/env bash

set -e


version=0.0.4-dev # script-mpe


test__version()
{
  echo $version
}
test___V() { test__version; }
test____version() { test__version; }


test__test()
{
  echo Ack.
}


## Main

test_main()
{
  # Do something if script invoked as 'x-test.sh'
  local scriptname=x-test \
      base="$(basename "$0" .sh)" \
      CWD subcmd=$1

  test_init || return

  case "$base" in $scriptname )

        #test -n "$scriptpath" || \
        #    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \

        #test -n "$verbosity" || verbosity=5

        local func=$(echo test__$subcmd | tr '-' '_') \
            failed= \
            ext_sh_sub=

        # lib_load str match main std stdio sys os src

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

test_init()
{
  local scriptname_old=$scriptname; export scriptname=$1-main-init

  CWD="$(dirname "$0")"
INIT_ENV="init-log strict 0 0-src 0-u_s dev ucache scriptpath std box" \
INIT_LIB="\$default_lib str str-htd logger-theme match main std stdio sys os box src src-htd" \
    . $CWD/tools/sh/init.sh || return
  export scriptname=$scriptname_old
}


# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  test "$1" != load-ext || lib_load=1
  test -n "${lib_load-}" || {
    test_main "$@"
  }
;; esac

# Id: script-mpe/0.0.4-dev x-test.sh
