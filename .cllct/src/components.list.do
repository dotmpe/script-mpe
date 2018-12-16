redo-ifchange "scm-status"
(
  unit_mode=boot scriptpath=$REDO_BASE . $REDO_BASE/util.sh

  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" &&
  lib_load build-htd &&

  build_components_id_path_map >"$REDO_PWD/$3"
)
redo-stamp <"$3"
