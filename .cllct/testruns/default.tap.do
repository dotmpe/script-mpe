set -- "$@" "$REDO_PWD/$3" "$(basename "$1" .tap)"

scriptpath=$REDO_BASE . $REDO_BASE/tools/sh/init.sh &&
  lib_load &&
  scriptname="do:$REDO_PWD:$1" &&
  cd "$REDO_BASE" &&
  lib_load build-test &&
  build_test_init &&
  paths="$( component_depnames "$5" | words_to_lines )" &&
  test -z "$paths" || {
    redo-ifchange $paths || exit $?
  }
  build_test "$5" >"$4"

redo-stamp <"$4"
