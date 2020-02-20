#!/usr/bin/env bash

# Shell env profile script

test -z "${sh_env_:-}" && sh_env_=1 || return 98 # Recursion

: "${CWD:="$PWD"}"
: "${sh_tools:="$CWD/tools/sh"}"
: "${ci_tools:="$CWD/tools/ci"}"

: "${build_tab:="build.txt"}"

set -o | grep -q pipefail || {
  . "$sh_tools/parts/env-strict.sh"
}

: "${APP_LBL:="Script.mpe"}" # No-Sync
: "${APP_ID:="script-mpe"}" # No-Sync
: "${SUITE:="Sh"}"
: "${sh_main_cmdl:="spec"}"
: "${U_S:="$CWD"}"
export scriptname=${scriptname:-"`basename -- "$0"`"}

test -n "${sh_util_:-}" || {

  . "$sh_tools/util.sh"
}

sleep 6

sh_include \
  env-0-1-lib-sys \
  print-color remove-dupes unique-paths \
  env-0-src
#SCRIPTPATH=
# XXXX:
#SCRIPTPATH=$CWD/contexts:$CWD/commands:$CWD:/home/travis/build/dotmpe/user-scripts/src/sh/lib:/home/travis/build/dotmpe/user-scripts/src/sh/lib:/home/travis/build/dotmpe/user-scripts/commands

test -z "${DEBUG:-}" -a -z "${CI:-}" ||
  print_yellow "${SUITE} Env parts" "$(suite_from_table "${build_tab}" "Parts" "${SUITE}" 0|tr '\n' ' ')" >&2

suite_source "${build_tab}" "${SUITE}" 0

test -z "${DEBUG:-}" || print_green "" "Finished sh:env ${SUITE} <$0>"

# Sync: U-S:
# Id: Script.mpe/0.0.4-dev tools/sh/env.sh
