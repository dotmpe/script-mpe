#!/usr/bin/env bash
set -euo pipefail

funcname="$(basename -- "$1" .func-deps)"
docid="$(basename -- "$(dirname "$1")" -lib)"
case "$docid" in
    default.func-deps ) exit 21 ;; # refuse to build non lib
    "*.func-deps" ) exit 22 ;; # refuse to build non lib
    * ) ;; esac

redo-ifchange "sh-libs.list"
  
# Transform target-name (docid) to original file-paths
# Should really have just one path for shell-lib components
path="$(ggrep '^'"$docid"'\>	' "sh-libs.list" | gsed 's/^[^\t]*\t//g')"

test -n "$path" -a -e "$REDO_BASE/$path" || { echo "No such path '$path'" >&2; exit 1; }
mkdir -p "$(dirname "$1")"

redo-ifchange functions/$docid-lib.func-list $REDO_BASE/$path

test ! -e "$1" -o -s "$1" || rm "$1"

# Pass filename to build routine
(
  CWD=$REDO_BASE . $REDO_BASE/tools/sh/init.sh &&

  scriptname="do:$REDO_PWD:$1" && {
    test -n "$docid" -a -n "$funcname" -a -n "$path" || {
      error "'$docid:$funcname' <$path>" 1
    } ; } &&
  mkdir -p "functions/$docid-lib/" &&
  cd "$REDO_BASE" &&
  lib_load build-htd && 
  build_lib_func_deps_list "$funcname" "$path" >"$REDO_PWD/$3"
)

redo-stamp <"$3"
test ! -e "$3" -o -s "$3" || rm "$3"
