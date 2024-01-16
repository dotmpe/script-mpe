#!/bin/sh

set -e

build_main()
{
  test -n "$1" || set -- static
  echo "Build Main: '$*'" >&2

  echo "Sourcing project CI env..." >&2
  # FIXME: get profile apart properly from libs, minimalize libs for static init
  scriptname=$1 . ./tools/ci/env.sh

  for lib in build*.lib.sh
  do
    grep -q "^$1()" "$lib" && {
      note "Found '$1' at '$lib'"
      lib_load $(basename "$lib" .lib.sh) &&
        std_info "Loaded $lib" || error "Loading $lib"
    } || continue
  done

  case "$1" in
      *static )
          ;;

      * )   test "0" = "$build_test_lib_load" && {

              build_test_init || return
            } || {
              test "0" = "$build_lib_load" && {

                build_init || return
              } || {

                echo "unknown init" >&2
                exit 1
              }
            }
            echo "Static init for '$1' OK" >&2
          ;;
  esac

  echo "Starting build..." >&2
  "$@"
}

echo build_main "$@"
build_main "$@"
