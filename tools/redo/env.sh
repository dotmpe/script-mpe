#!/usr/bin/env bash
set -euo pipefail

# TODO: clean up other envs and let redo use CI or build or main env?

#test "$PWD" != "." || {
#  ${LOG:-$U_S/tools/sh/log.sh} \
#    alert "" "Unknown CWD" "$PWD $CWD $0 $*" 1
#}

: "${SUITE:="Main"}"
true "${package_build_tool:="redo"}"
true "${init_sh_libs:="os sys str log shell script $package_build_tool build"}"
true "${build_parts_bases:="$HOME/bin/tools/redo/parts $UCONF/tools/redo/parts $U_S/tools/redo/parts"}"
true "${build_parts_bases:="$(for base in ${!package_tools_redo_parts_bases__*}; do eval "echo ${!base}"; done )"}"
true "${build_main_targets:="${package_tools_redo_targets_main-"all help build test"}"}"
true "${build_all_targets:="${package_tools_redo_targets_all-"build test"}"}"
true "${DEBUG:=${REDO_DEBUG-${DEBUG-}}}"
export verbosity="${verbosity:=${v:-3}}"
export quiet="${quiet:=${q:-0}}"

. ${CWD:="$PWD"}/tools/ci/env.sh

$LOG "info" "" "Started redo env" "${CWD}/tools/ci/env.sh"
# Sync: U-S:
