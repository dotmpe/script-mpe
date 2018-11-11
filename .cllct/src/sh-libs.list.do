redo-ifchange "sh-files.list" "$REDO_BASE/build.lib.sh" "$REDO_BASE/package.yaml"

(
  scriptpath=$REDO_BASE . $REDO_BASE/util.sh && lib_load

  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" &&
  lib_load build &&
  build_init && build_package_script_lib_list >"$REDO_PWD/$3"
  test -s "$REDO_PWD/$3" || {
    error "No libs found!" 1
  }
)

echo "Listed $(wc -l "$3"|awk '{print $1}') sh libs "  >&2
redo-stamp <"$3"
