#!/usr/bin/env bash
set -euo pipefail

scriptpath=$REDO_BASE . $REDO_BASE/tools/sh/init.sh &&
lib_load &&
cd "$REDO_BASE" &&
./build.sh redo_deps | xargs rm
