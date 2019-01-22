#!/usr/bin/env bash
# CI suite stage 2. See .travis.yml
set -eu
export_stage install && announce_stage

# XXX: Call for $ENV_NAME setup, see +U_s

#lib_load env-deps web
#lib_load std-ht std build-htd std

$LOG note "" "Running install steps" "$(suite_from_table "${build_tab}" Parts $SUITE 2 | tr '\n' ';')"
suite_run "${build_tab}" $SUITE 2

ci_announce "Sourcing env (II)..."
$INIT_LOG "info" "" "Stages:" "$ci_stages"
unset SCRIPTPATH ci_env_ sh_env_ sh_util_ ci_util_ sh_usr_env_
. "${ci_tools}/env.sh"
ci_stages="$ci_stages ci_env_2 sh_env_2"
ci_env_2_ts=$ci_env_ts sh_env_2_ts=$sh_env_ts sh_env_2_end_ts=$sh_env_end_ts
$INIT_LOG "info" "" "Stages:" "$ci_stages"

stage_id=install close_stage
set +eu
# Sync: U-S:
