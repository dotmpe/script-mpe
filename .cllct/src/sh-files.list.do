redo-ifchange "scm-status"

(
  scriptpath=$REDO_BASE . $REDO_BASE/util.sh && lib_load
  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" &&
  lib_load build &&

  list_sh_files >"$REDO_PWD/$3"

  test -s "$REDO_PWD/$3" || {
    error "No shell script files found!" 1
  }
)

echo "Listed $(wc -l "$3"|awk '{print $1}') sh files"  >&2
redo-stamp <$3
