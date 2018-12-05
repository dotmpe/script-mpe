#!/bin/sh


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
      default_lib="os std sys str stdio src main argv match vc shell"

  test -n "$__load_lib" || local __load_lib=1

  #test -n "$1" || set -- $default_lib
  test -n "$1" || return 1
  while test -n "$1"
  do
    lib_id=$(printf -- "${1}" | tr -Cs 'A-Za-z0-9_' '_')
    test -n "$lib_id" || {
      $LOG error lib "err: lib_id=$lib_id" "" 1 || return
    }
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
        test -n "$f_lib_path" || {
          $LOG error "lib" "No path for lib '$1'" "" 1 || return
        }
        . $f_lib_path

        # again, func_exists is in sys.lib.sh. But inline here:
        type ${lib_id}_lib_load  2> /dev/null 1> /dev/null && {
          ${lib_id}_lib_load || {
            $LOG error "lib" "in lib-load $1 ($?)" 1 || return
          }
        }

        eval ENV_SRC=\""$ENV_SRC $f_lib_path"\"
        eval ${lib_id}_lib_loaded=1
        $LOG info "lib" "Finished loading ${lib_id}: OK"
        unset lib_id
    }
    shift
  done
}

util_boot()
{
  test -n "$__load_boot" || {
    __load_boot="$(basename "$0" .sh)"
  }
  test -z "$util_mode" -a -n "$1" && {
    util_mode=$1
  } || {
    test -n "$1" || set -- "$util_mode"
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
      SCRIPTPATH=$scriptpath
    } || {
      exit 106 # No SCRIPTPATH or scriptpath env
    }
  }
  test -n "$LOG" || export LOG=$scriptpath/log.sh
  lib_load $default_lib
}

case "$0" in

  "-"*|"" ) ;;

  * )

      test -n "$f_lib_load" && {
        # never
        echo "util.sh assert failed: f-lib-load is set ($0: $*)" >&2
        exit 1

      } || {

        test -n "$util_mode" || util_mode=$__load
        case "$util_mode" in

          # Setup SCRIPTPATH and include other scripts
          boot|main )
              util_boot "$@"
            ;;

        esac
      }
      test -n "$SCRIPTPATH" || {
        util_init
      }
      case "$util_mode" in
        boot )
            lib_load $default_lib
          ;;
        #ext|load-*|* ) ;; # External include, do nothing
      esac
    ;;
esac

# Id: script-mpe/0.0.4-dev util.sh
