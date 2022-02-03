#!/usr/bin/env bash
shopt -s extdebug
set -euETo pipefail

# TODO: clean up other envs and let redo use CI or build or main env?

export scriptname="redo[$$]:$0"

: "${SUITE:="Main"}"
true "${package_build_tool:="redo"}"
true "${init_sh_libs:="os sys str log shell script $package_build_tool build"}"
true "${build_parts_bases:="$(for base in ${!package_tools_redo_parts_bases__*}; do eval "echo ${!base}"; done )"}"
true "${build_parts_bases:="$HOME/bin/tools/redo/parts $UCONF/tools/redo/parts $U_S/tools/redo/parts"}"
true "${build_main_targets:="${package_tools_redo_targets_main-"all help build test"}"}"
true "${build_all_targets:="${package_tools_redo_targets_all-"build test"}"}"
true "${DEBUG:=${REDO_DEBUG-${DEBUG-}}}"
export verbosity="${verbosity:=${v:-3}}"
export quiet="${quiet:=${q:-0}}"

# XXX: unless CI is on, we assume we are interactive
export STD_INTERACTIVE=1
export COLORIZE=1

export UC_QUIET=1
export UC_SYSLOG_OFF=1
#export UC_LOG_BASE="redo[$$]"
#STD_SYSLOG_LEVEL=${v:-5}

. ${CWD:="$REDO_BASE"}/tools/ci/env.sh

$LOG "info" "" "Started redo env" "${CWD}/tools/redo/env.sh"
# Sync: U-S:
