#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "sh-files.list" "$REDO_BASE/package.yaml"

(
  scriptname="do:$REDO_PWD:$1"
  util_mode=boot CWD=$REDO_BASE . $REDO_BASE/tools/sh/init.sh

  cd "$REDO_BASE" &&
  lib_require build-htd main match sys-htd vc-htd src package &&
  lib_init build-htd main match sys-htd vc-htd src package &&
  build_init && build_package_script_lib_list >"$REDO_PWD/$3"
  test -s "$REDO_PWD/$3" || {
    error "No libs found!" 1
  }
)

echo "Listed $(wc -l "$3"|awk '{print $1}') sh libs "  >&2
redo-stamp <"$3"
