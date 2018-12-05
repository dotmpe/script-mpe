redo-ifchange "sh-files.list"

(
  util_mode=boot scriptpath=$REDO_BASE . $REDO_BASE/util.sh

  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" &&
  lib_load build &&
# FIXME: lots of OSHC errors in scripts much up stderr
  functions_execs < $REDO_PWD/sh-files.list 2>/dev/null >"$REDO_PWD/$3"
)

redo-stamp <"$3"
