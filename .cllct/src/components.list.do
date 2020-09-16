#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "scm-status"
(
  true "${package_build_tool:="redo"}"
  . ~/bin/.env.sh &&
  init_sh_libs="$init_sh_libs build-htd" \
    unit_mode=boot CWD=$REDO_BASE . $REDO_BASE/tools/sh/init.sh

  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" && build_components_id_path_map >"$REDO_PWD/$3"
)
redo-stamp <"$3"
