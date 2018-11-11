scriptpath=$REDO_BASE . $REDO_BASE/util.sh &&
lib_load &&
cd "$REDO_BASE" &&
./build.sh redo_deps | xargs rm
