#!/bin/sh

# FIXME: comment format:
# [return codes] [exit codes] func-id [flags] pos-arg-id.. $name-arg-id..
# Env: $name-env-id
# Description.


lib_path_exists()
{
  test -e "$1/$2.lib.sh" || return 1
  echo "$1/$2.lib.sh"
}

# Echo every occurence of *.lib.sh on SCRIPTPATH
lib_path() # local-name path-var-name
{
  test -n "$2" || set -- "$1" SCRIPTPATH
  lookup_test=lib_path_exists lookup_path $2 "$1"
}

# Lookup and load sh-lib on SCRIPTPATH
lib_load()
{
  test -n "$LOG" || exit 102
  local lib_id= f_lib_loaded= f_lib_path=
  # __load_lib: true if inside util.sh:lib-load
  test -n "$default_lib" ||
      export default_lib="os std sys str stdio src main argv match vc shell"

  test -n "$__load_lib" || local __load_lib=1
  test -n "$1" || set -- $default_lib
  while test -n "$1"
  do
    lib_id=$(printf -- "${1}" | tr -Cs 'A-Za-z0-9_' '_')
    test -n "$lib_id" || { echo "err: lib_id=$lib_id" >&2; exit 1; }
    f_lib_loaded=$(eval printf -- \"\$${lib_id}_lib_loaded\")

    test -n "$f_lib_loaded" || {

        # Note: the equiv. code using sys.lib.sh is above, but since it is not
        # loaded yet keep it written out using plain shell.
        f_lib_path="$( echo "$SCRIPTPATH" | tr ':' '\n' | while read sp
          do
            test -e "$sp/$1.lib.sh" || continue
            echo "$sp/$1.lib.sh"
            break
          done)"
        test -n "$f_lib_path" || { $LOG error "No path for lib '$1'" ; exit 1; }
        . $f_lib_path

        # again, func_exists is in sys.lib.sh. But inline here:
        type ${lib_id}_lib_load  2> /dev/null 1> /dev/null && {
           ${lib_id}_lib_load || error "in lib-load $1 ($?)" 1
        }

        eval ENV_SRC=\""$ENV_SRC $f_lib_path"\"
        #echo "'$ENV_SRC' '$f_lib_path'" >&2
        eval ${lib_id}_lib_loaded=1
        #echo "note: ${lib_id}: 1" >&2
        unset lib_id
    }
    shift
  done
}

dir_load()
{
  test -n "$1" || error dir-expected 1
  test -n "$2" || set -- "$1" .sh
  for scr in $1/*$2
  do
    . $scr
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
}

util_init()
{
  test -n "$SCRIPTPATH" && {
    test -n "$scriptpath" || {
      scriptpath="$(echo "$SCRIPTPATH" | sed 's/^.*://g')"
    }
  } || {
    test -n "$scriptpath" && {
      export SCRIPTPATH=$scriptpath
    } || {
      exit 106 # No SCRIPTPATH or scriptpath env
    }
  }
  test -n "$LOG" || export LOG=$scriptpath/log.sh
  lib_load
}

case "$0" in

  "-"*|"" ) ;;

  * )

      test -n "$f_lib_load" && {
        # never
        echo "util.sh assert failed: f-lib-load is set ($0: $*)" >&2
        exit 1

      } || {

        test -n "$__load_mode" || __load_mode=$__load
        case "$__load_mode" in

          # Setup SCRIPTPATH and include other scripts
          boot|main )
              util_boot "$@"
            ;;

        esac
      }
      test -n "$SCRIPTPATH" || {
        util_init
      }
      case "$__load_mode" in
        boot )
            lib_load
          ;;
        #ext|load-*|* ) ;; # External include, do nothing
      esac
    ;;
esac

# Id: script-mpe/0.0.4-dev util.sh
