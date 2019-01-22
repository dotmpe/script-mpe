#!/usr/bin/env bash
# CI suite stage 1. See .travis.yml
set -ueo pipefail

: "${SUITE:="CI"}"
: "${CWD:="$PWD"}"

echo "Sourcing env (I)" >&2
: "${ci_tools:="$CWD/tools/ci"}"
. "${ci_tools}/env.sh"

ci_stages="$ci_stages ci_env_1 sh_env_1"
ci_env_1_ts=$ci_env_ts sh_env_1_ts=$sh_env_ts sh_env_1_end_ts=$sh_env_end_ts

# Set timestamps for each stage start/end XXX: and stack
export_stage before-install before_install && announce_stage

$LOG note "" "Sourcing init parts" "$(suite_from_table "build.txt" Parts $SUITE 1 | tr '\n' ' ')"
suite_source "build.txt" $SUITE 1
test $SKIP_CI -eq 0 || exit 0

stage_id=before_install close_stage
set +euo pipefail
# Sync: U-S:
# Id: script-mpe/0.0.4-dev tools/ci/before-install.sh
