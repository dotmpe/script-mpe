#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "scm-status"
(
  CWD=$REDO_BASE &&
  true "${package_build_tool:="redo"}"
  . ~/.local/etc/profile.d/_local.sh &&
  init_sh_libs="$init_sh_libs build-htd" \
    unit_mode=boot . $REDO_BASE/tools/sh/init.sh

  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" && build_components_id_path_map >"$REDO_PWD/$3"
)
redo-stamp <"$3"
