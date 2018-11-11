set -- "$@" "$REDO_PWD/$3" "$(basename "$1" .list)"
redo-ifchange \
    "$REDO_BASE/.cllct/src/scm-status" \
    "$REDO_BASE/.cllct/specsets/$5.excludes"

scriptpath=$REDO_BASE . $REDO_BASE/util.sh &&
  lib_load &&
  scriptname="do:$REDO_PWD:$1" &&
  cd "$REDO_BASE" &&
  lib_load build-test &&
  build_test_init &&
  expand_spec_src "$5" "$5.excludes" >"$4" &&
  test -s "$4" && redo-stamp <"$4" || rm "$4"
