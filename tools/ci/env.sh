#!/usr/bin/env bash

# Boilerplate env for CI scripts

test -z "${ci_env_:-}" && ci_env_=1 || exit 98 # Recursion

# FIXME: generate local static env
true "${BIN:="$HOME/bin"}"
test ! -e $BIN/.env.sh || . $BIN/.env.sh

: "${CS:="dark"}"
export CS
: "${CWD:="$PWD"}"
: "${LOG:="$CWD/tools/sh/log.sh"}"

# FIXME: handle various U-S setups, and make script.mpe completely dependent on
# scripts in U-S, remove all but specific local tools
# if test -z "${TRAVIS-}"
# test -n "${U_S-}" ||
#   $LOG "error" "" "Expected U-S env" "" 1
#
# test -d $U_S/.git || {
#   test "${ENV_DEV-}" = "1" && {
#     {
#       test ! -d "$U_S" || rm -rf "$U_S"
#       git clone https://github.com/dotmpe/user-scripts.git $U_S
#     }
#     ( cd $U_S/ && git fetch --all &&
#         git checkout feature/docker-ci &&
#         git pull origin feature/docker-ci )
#   } ||
#       $LOG "error" "" "Expected U-S checkout" "" 1
# }
test "${env_strict_-}" = "0" || {
  . "$CWD/tools/sh/parts/env-strict.sh" && env_strict_=$?; }
. "$CWD/tools/sh/parts/env-init-log.sh"
. "$CWD/tools/sh/parts/debug-exit.sh"
. "$CWD/tools/sh/parts/env-0-1-lib-sys.sh"

ci_env_ts=$($gdate +"%s.%N")
ci_stages="${ci_stages:-} ci_env"

test "${DEBUG-}" = "1" && set -x

: "${SUITE:="CI"}"
#: "${DEBUG:=1}"
: "${keep_going:=1}" # No-Sync

sh_env_ts=$($gdate +"%s.%N")
ci_stages="$ci_stages sh_env"

. "${CWD}/tools/sh/env.sh"

sh_env_end_ts=$($gdate +"%s.%N")

test -n "${ci_util_:-}" || {

  . "${ci_tools:="$CWD/tools/ci"}/util.sh"
}

test -n "${IS_BASH:-}" || $INIT_LOG error "Not OK" "Need to know shell dist" "" 1

# XXX: lib_load build-htd env-deps web # No-Sync

$INIT_LOG note "" "CI Env pre-load time: $(echo "$sh_env_ts - $ci_env_ts"|bc) seconds"
ci_env_end_ts=$($gdate +"%s.%N")

$INIT_LOG note "" "Sh Env load time: $(echo "$ci_env_end_ts - $ci_env_ts"|bc) seconds"
test ${verbosity:-${v:-3}} -lt 4 ||
  print_yellow "ci:env:${SUITE}" "Starting: $0 ${_ENV-} #$#:'$*'" >&2

# Sync: U-S:
# Id: Script.mpe/0.0.4-dev tools/ci/env.sh
