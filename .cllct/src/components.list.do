#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "scm-status"
(
  unit_mode=boot CWD=$REDO_BASE . $REDO_BASE/tools/sh/init.sh

  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" &&
  lib_load build-htd && lib_init &&
  build_components_id_path_map >"$REDO_PWD/$3"
)
redo-stamp <"$3"
