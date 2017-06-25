#!/bin/sh

set -e


# FIXME: comment format:
# [return codes] [exit codes] func-id [flags] pos-arg-id.. $name-arg-id..
# Env: $name-env-id
# Description.


lib_load()
{
  local f_lib_load= f_lib_path=
  test -n "$__load_lib" || local __load_lib=1
  test -n "$1" || set -- str sys os std stdio src match main argv
  while test -n "$1"
  do
    f_lib_path="$( echo "$SCRIPTPATH" | tr ':' '\n' | while read scriptpath
      do
        test -e "$scriptpath/$1.lib.sh" || continue
        echo "$scriptpath/$1.lib.sh"
      done)"
    test -n "$f_lib_path" || error "No path for lib '$1'" 1
    . $f_lib_path load-ext
    f_lib_load=$(printf "${1}" | tr -Cs 'A-Za-z0-9_' '_')_lib_load
    # func_exists, then call
    type ${f_lib_load} 2> /dev/null 1> /dev/null && {
      ${f_lib_load}
    }
    shift
  done
}

util_boot()
{
  test "$(basename "$(dirname "$0")")" = "bin" && {
    export scriptpath="$HOME/bin"
  } || {
    export scriptpath="$(dirname "$0")"
  }
}

util_init()
{
	export SCRIPTPATH="$HOME/bin"
	test -n "$scriptpath" -a "$scriptpath" = "$SCRIPTPATH" ||
      export SCRIPTPATH="$scriptpath:$SCRIPTPATH"
  lib_load
}


case "$0" in
  "-"*|"" ) ;;
  * )
      test -n "$f_lib_load" || {
        case "$__load_mode" in
          # Setup SCRIPTPATH and include other scripts
          boot|main )
              util_boot "$@"
            ;;
        esac
        test -n "$SCRIPTPATH" || {
          util_init
        }
      }
      case "$__load_mode" in
        load-* ) ;; # External include, do nothing
        boot )
            lib_load
          ;;
      esac
    ;;
esac

# Id: script-mpe/0.0.4-dev util.sh
