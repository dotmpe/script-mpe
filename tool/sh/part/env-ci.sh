#!/usr/bin/env bash

: "${ci_stages:=}"
: "${stages_done:=}"

: "${BRANCH_NAME:="$(git rev-parse --abbrev-ref HEAD)"}"

test -n "${TRAVIS_TIMER_START_TIME:-}" ||
  : "${TRAVIS_TIMER_START_TIME:=$($gdate +%s%N)}"

travis_ci_timer_ts=$(echo "$TRAVIS_TIMER_START_TIME"|sed 's/\([0-9]\{9\}\)$/.\1/')

: "${TRAVIS_BRANCH:=$BRANCH_NAME}"
: "${TRAVIS_JOB_ID:=-1}"
: "${TRAVIS_JOB_NUMBER:=-1}"
: "${TRAVIS_BUILD_ID:=}"
: "${GIT_COMMIT:="$(git rev-parse HEAD)"}"
: "${TRAVIS_COMMIT:="$GIT_COMMIT"}"
: "${TRAVIS_COMMIT_RANGE:="$COMMIT_RANGE"}"
: "${BUILD:=".build"}" ; B=$BUILD

: "${SHIPPABLE:=}"

: "${TEST_SPECS:=}" # No-Sync

: "${dckr_pref:=}"
: "${USER:="`whoami`"}"
test  "$USER" = "treebox" && : "${dckr_pref:="sudo "}"

: "${U_S:="$HOME/.basher/cellar/packages/dotmpe/user-scripts"}"
: "${u_s_version:="feature/docker-ci"}"
: "${package_build_tool:="redo"}"
: "${sh_tools:="$CWD/tool/sh"}"
: "${ci_tools:="$CWD/tool/ci"}"
# XXX: rename or reserve or something
: "${script_util:="$sh_tools"}"
export scriptname=${scriptname:-"`basename -- "$0"`"}

: "${verbosity:=5}"
: "${LOG:="$CWD/tool/sh/log.sh"}"
: "${INIT_LOG:=$LOG}"

# Sync: U-S:
