#!/usr/bin/env bash
set -euo pipefail

# TODO: clean up other envs and let redo use CI or build or main env?

: "${SUITE:="Main"}"
true "${package_build_tool:="redo"}"
true "${init_sh_libs:="os sys str log shell script $package_build_tool build"}"
true "${DEBUG:=${REDO_DEBUG-${DEBUG-}}}"

. ${CWD:="$PWD"}/tools/ci/env.sh

$LOG "info" "" "Started redo env" "$_ENV"
# Sync: U-S:
