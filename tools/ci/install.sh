#!/usr/bin/env bash
# See .travis.yml

set -u
export_stage install && announce_stage

# XXX: Call for dev setup, see +U_s
#$script_util/parts/init.sh all

ci_announce "Sourcing env (II)..."
$LOG "info" "" "Stages:" "$ci_stages"
unset SCRIPTPATH ci_env_ sh_env_ sh_util_ ci_util_ sh_usr_env_
. "${ci_util}/env.sh"
ci_stages="$ci_stages ci_env_2 sh_env_2"
ci_env_2_ts=$ci_env_ts sh_env_2_ts=$sh_env_ts sh_env_2_end_ts=$sh_env_end_ts
$LOG "info" "" "Stages:" "$ci_stages"

echo "Script-Path:"
echo "$SCRIPTPATH" | tr ':' '\n'
export SCRIPTPATH

stage_id=install close_stage
set +u
