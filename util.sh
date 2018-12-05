#!/bin/sh

# Module for lib_load
# FIXME: comment format:
# [return codes] [exit codes] func-id [flags] pos-arg-id.. $name-arg-id..
# Env: $name-env-id
# Description.

lib_lib_load()
{
  test -n "$default_lib" ||
      default_lib="os std sys sys-htd str stdio src main argv match vc shell"
}

lib_lib_init()
{
  test -n "$LOG" || return 102
}

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

lib_lookup()
{
  lib_path "$1" | head -n 1
}

# Lookup and load sh-lib on SCRIPTPATH
lib_load()
{
  test -n "$1" || return 1

  test -n "$LOG" || exit 102
  local lib_id= f_lib_loaded= f_lib_path=

  # __load_lib: true if inside util.sh:lib-load
  test -n "$__load_lib" || local __load_lib=1
  while test $# -gt 0
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
        . "$f_lib_path"

        # again, func_exists is in sys.lib.sh. But inline here:
        type ${lib_id}_lib_load  2> /dev/null 1> /dev/null && {
          ${lib_id}_lib_load || {
            $LOG error "lib" "in lib-load $1 ($?)" 1 || return
          }
        } || true

        eval "LIB_SRC=\"$LIB_SRC $f_lib_path\""
        eval ${lib_id}_lib_loaded=1
        lib_loaded="$lib_loaded $lib_id"
        # FIXME sep. profile/front-end for shell vs user-scripts
        # $LOG info "lib" "Finished loading ${lib_id}: OK"
        unset lib_id
    }
    shift
  done
}

# Verify lib was loaded or bail out
lib_assert()
{
  test $# -gt 0 || return
  while test $# -gt 0
  do
    test "$(eval "echo \$${1}_lib_loaded")" = "1" || {
      $LOG error lib "Assert loaded $1" "" 1
      return 1
    }
    shift
  done
}

# After loaded, execute <lib-id>_lib_init() if defined for each lib in load seq.
lib_init()
{
  test $# -gt 0 || set -- $lib_loaded

  while test $# -gt 0
  do
    type ${1}_lib_init 2> /dev/null 1> /dev/null && {
      ${1}_lib_init || {
        $LOG error "lib" "in lib-init $1 ($?)" 1 || return
      }
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
}

# Main

case "$0" in

  "-"*|"" ) ;;

  * )

      test -n "$f_lib_load" && {
        # never
        echo "util.sh assert failed: f-lib-load is set ($0: $*)" >&2
        exit 1

      } || {

        test -n "$util_mode" ||
          $LOG error util "Set util_mode before sourcing util.sh" "" 2
      }
      test -n "$SCRIPTPATH" || {
        util_init
      }
      case "$util_mode" in
        lib )
            lib_lib_load
          ;;
        * ) ;;
      esac
      case "$util_mode" in
        boot )
            lib_lib_load && lib_load $default_lib
          ;;
        #ext|load-*|* ) ;; # External include, do nothing
        * ) ;;
      esac
    ;;
esac

# Id: script-mpe/0.0.4-dev util.sh
