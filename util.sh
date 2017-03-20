#!/bin/sh

set -e


# FIXME: comment format:
# [return codes] [exit codes] func-id [flags] pos-arg-id.. $name-arg-id..
# Env: $name-env-id
# Description.


lib_load()
{
  local f_lib_load=
  test -n "$__load_lib" || local __load_lib=1
  test -n "$1" || set -- str sys os std stdio src match main argv
  while test -n "$1"
  do
    . $scriptpath/$1.lib.sh load-ext
    f_lib_load=$(printf "${1}" | tr -Cs 'A-Za-z0-9_' '_')_load
    # func_exists, then call
    type ${f_lib_load} 2> /dev/null 1> /dev/null && {
      ${f_lib_load}
    }
    shift
  done
}

util_init()
{
  lib_load
  #sys_load
  #str_load
  #std_load
}


case "$0" in
  "-"*|"" ) ;;
  * )

      test -z "$__load_lib" || set -- "load-ext"
      case "$1" in
        load-* ) ;; # External include, do nothing
        boot )
            test -n "$scriptpath" || scriptpath="$(dirname "$0")"
            lib_load
          ;;
        * ) # Setup SCRIPTPATH and include other scripts

            test -n "$scriptpath"
            lib_load
          ;;
      esac
    ;;
esac

# Id: script-mpe/0.0.4-dev util.sh
