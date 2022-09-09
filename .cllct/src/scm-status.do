#!/usr/bin/env bash
set -euo pipefail

redo-ifchange "$REDO_BASE/.git/index" "$REDO_BASE/.git/HEAD"

(
  cd "$REDO_BASE" &&
  { git describe --always && git status | md5sum - ; } >"$REDO_PWD/$3"
)

redo-stamp <"$3"
