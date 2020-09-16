#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "scm-status"

(
  . $REDO_BASE/tools/redo/env.sh &&
  scriptname="do:$REDO_PWD:$1"
  init_sh_libs="$init_sh_libs build-htd match src std sys-htd vc-htd package main" \
  util_mode=boot CWD=$REDO_BASE \
    . $REDO_BASE/tools/sh/init.sh &&

  cd "$REDO_BASE" &&
  build_init && list_sh_files >"$REDO_PWD/$3"
  test -s "$REDO_PWD/$3" || {
    $LOG error "" "No shell script files found!" "$REDO_PWD/$3" 1
  }
)

echo "Listed $(wc -l "$3"|awk '{print $1}') sh files"  >&2
redo-stamp <$3
