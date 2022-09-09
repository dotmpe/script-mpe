#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "sh-libs.list"

lib_id="$(basename -- "$1" -lib.func-list)" &&
case "$lib_id" in
    default.functions-list ) exit 21 ;; # refuse to build non lib
    "*.func-list" ) exit 22 ;; # refuse to build non lib
    * ) ;; esac &&

# Transform target-name (lib_id) to original file-paths
# Should really have just one path for shell-lib components
paths="$(grep '^'"$lib_id"'\>	' "sh-libs.list" | sed 's/^[^\t]*\t//g')" &&

test -n "$paths" || {
  $LOG warn "$1" "No paths for '$lib_id'"
  exit 0
}
mkdir -p "$(dirname "$1")"

# Redo if libs associated have changed.
# NOTE: would be nice to track function-source instead
redo-ifchange $( echo "$paths" | sed 's#^\(\.\/\)\?#'"$REDO_BASE/"'#g' )

test ! -e "$1" -o -s "$1" || rm "$1"

# Pass filename to build routine
(
  . $REDO_BASE/tools/redo/env.sh &&
  init_sh_libs="$init_sh_libs match src sys std package functions build-htd" &&
  util_mode=boot CWD=$REDO_BASE \
    . $REDO_BASE/tools/sh/init.sh

  scriptname="do:$REDO_PWD:$1" && {
    test -n "$lib_id" -a -n "$paths" || {
      error "'$lib_id' <$paths>" 1 ;
    } ; } &&
  cd "$REDO_BASE" &&
  build_init && build_lib_func_list $paths >"$REDO_BASE/$REDO_PWD/$3"
)

echo "Listed $(wc -l "$3"|awk '{print $1}') shell functions from '$lib_id' lib"  >&2
redo-stamp <"$3"
test ! -e "$3" -o -s "$3" || rm "$3"
