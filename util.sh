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
  test -n "$__load_boot" || {
    export __load_boot="$(basename "$0" .sh)"
  }
  test -z "$__load_mode" -a -n "$1" && {
    export __load_mode=$1
  } || {
    test -n "$1" || set -- "$__load_mode"
  }

  #test \( -n "$SCRIPTPATH" -o -n "$scriptpath" \) -a -z "$__load_boot" || {
  #  echo "[~/bin/util.sh] Initializing '$__load_boot' SCRIPTPATH ($*)" >&2
  #}

  export SCRIPTPATH="$(dirname "$0"):$HOME/bin"
}

util_init()
{
  test -n "$SCRIPTPATH" && {
    test -n "$scriptpath" || {
      export scriptpath="$(echo "$SCRIPTPATH" | sed 's/^.*://g')"
    }
  } || {
    test -n "$scriptpath" && {
      export SCRIPTPATH=$scriptpath
    } || {
      exit 106
    }
  }

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
