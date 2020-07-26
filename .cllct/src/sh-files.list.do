#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "scm-status"

(
  scriptname="do:$REDO_PWD:$1"
  util_mode=boot CWD=$REDO_BASE . $REDO_BASE/tools/sh/init.sh &&
  cd "$REDO_BASE" &&
  lib_require build-htd sys-htd vc-htd main &&
  list_sh_files >"$REDO_PWD/$3"
  test -s "$REDO_PWD/$3" || {
    error "No shell script files found!" 1
  }
)

echo "Listed $(wc -l "$3"|awk '{print $1}') sh files"  >&2
redo-stamp <$3
