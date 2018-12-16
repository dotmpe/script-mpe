(
  test -n "$scriptpath" ||
      { util_mode=ext scriptpath=$REDO_BASE . $REDO_BASE/util.sh && lib_load; }

  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" &&
  lib_load build-htd &&
  build_init && build_doc_src_sh_calls_1_gv "$(basename "$1" -lib.calls-1.dot.gv)" >"$REDO_PWD/$3"
)

redo-stamp <"$3"
