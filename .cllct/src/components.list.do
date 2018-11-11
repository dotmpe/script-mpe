redo-ifchange "scm-status"
(
  scriptpath=$REDO_BASE . $REDO_BASE/util.sh && lib_load

  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" &&
  lib_load build &&

  build_components_id_path_map >"$REDO_PWD/$3"
)
redo-stamp <"$3"
