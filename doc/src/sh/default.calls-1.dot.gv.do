#!/usr/bin/env bash

(
  init_sh_libs="argv str-htd src package build-htd" \
  CWD=$REDO_BASE . $REDO_BASE/tools/sh/init.sh &&

  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" &&
  build_init && build_doc_src_sh_calls_1_gv "$(basename "$1" -lib.calls-1.dot.gv)" >"$REDO_PWD/$3"
)

redo-stamp <"$3"
