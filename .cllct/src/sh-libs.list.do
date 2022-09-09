#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "sh-files.list" "$REDO_BASE/package.yaml"

(
  . $REDO_BASE/tools/redo/env.sh &&
  scriptname="do:$REDO_PWD:$1"
  init_sh_libs="$init_sh_libs build-htd match src std sys-htd vc-htd package main" \
  util_mode=boot \
    . $REDO_BASE/tools/sh/init.sh

  cd "$REDO_BASE" &&
  build_init && build_package_script_lib_list >"$REDO_PWD/$3"
  test -s "$REDO_PWD/$3" || {
    error "No libs found!" 1
  }
)

echo "Listed $(wc -l "$3"|awk '{print $1}') sh libs "  >&2
redo-stamp <"$3"
