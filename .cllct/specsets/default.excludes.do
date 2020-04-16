set -- "$@" "$REDO_PWD/$3" "$(basename "$1" .excludes)"
redo-ifchange \
    "$REDO_BASE/build-htd.lib.sh" \
    "$REDO_BASE/build-test.lib.sh"

scriptpath=$REDO_BASE . $REDO_BASE/tools/sh/init.sh &&
  lib_load &&
  scriptname="do:$REDO_PWD:$1" &&
  cd "$REDO_BASE" &&
  lib_load build-test &&
  build_test_init &&
  expand_spec_ignores "$5" >"$4" &&
  test -s "$4" && redo-stamp <"$4" || rm "$4"
