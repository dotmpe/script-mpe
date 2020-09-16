#!/usr/bin/env bash

# CI suite stage 2.

export_stage install && announce_stage

$LOG note "" "Running install steps" "$(suite_from_table "${build_tab}" Parts $SUITE 2 | tr '\n' ';')"
suite_run "${build_tab}" $SUITE 2

ci_announce "Sourcing env (II)..."
$INIT_LOG "info" "" "1. Stages:" "$ci_stages"
unset SCRIPTPATH ci_env_ sh_env_ sh_util_ ci_util_ sh_usr_env_
. "${ci_tools}/env.sh"

# Save times of second env.sh source
ci_stages="$ci_stages ci_env_2 sh_env_2"
ci_env_2_ts=$ci_env_ts sh_env_2_ts=$sh_env_ts sh_env_2_end_ts=$sh_env_end_ts
$INIT_LOG "info" "" "2. Stages:" "$ci_stages"

stage_id=install close_stage
# Sync: U-S:
