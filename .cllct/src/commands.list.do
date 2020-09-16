#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "sh-files.list"
(
  . $REDO_BASE/tools/redo/env.sh &&
  init_sh_libs="$init_sh_libs build-htd functions" \
    util_mode=boot CWD=$REDO_BASE . $REDO_BASE/tools/sh/init.sh

  scriptname="do:$REDO_PWD:$1"
  cd "$REDO_BASE" && functions_execs < $REDO_PWD/sh-files.list 2>/dev/null \
      | sort -u >"$REDO_PWD/$3"
)
redo-stamp <"$3"
