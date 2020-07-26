#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "sh-libs.list"

docid="$(basename -- "$1" -lib.func-list)" &&
case "$docid" in
    default.functions-list ) exit 21 ;; # refuse to build non lib
    "*.func-list" ) exit 22 ;; # refuse to build non lib
    * ) ;; esac &&

# Transform target-name (docid) to original file-paths
# Should really have just one path for shell-lib components
paths="$(grep '^'"$docid"'\>	' "sh-libs.list" | sed 's/^[^\t]*\t//g')" &&

mkdir -p "$(dirname "$1")"

test -n "$paths" || {
  $LOG warn "$1" "No paths for '$docid'"
  exit 0
}

redo-ifchange $( echo "$paths" | sed 's#^\(\.\/\)\?#'"$REDO_BASE/"'#g' )

test ! -e "$1" -o -s "$1" || rm "$1"

# Pass filename to build routine
(
  util_mode=boot CWD=$REDO_BASE . $REDO_BASE/tools/sh/init.sh

  scriptname="do:$REDO_PWD:$1" && {
    test -n "$docid" -a -n "$paths" || {
      error "'$docid' <$paths>" 1 ;
    } ; } &&
  cd "$REDO_BASE" &&
  lib_load build-htd functions &&
  build_lib_func_list $paths >"$REDO_BASE/$REDO_PWD/$3"
)

echo "Listed $(wc -l "$3"|awk '{print $1}') sh funcs in $docid lib"  >&2
redo-stamp <"$3"
test ! -e "$3" -o -s "$3" || rm "$3"
