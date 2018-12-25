#!/bin/sh

export_stage install && announce_stage

# TODO: see +Us Call for dev setup
$script_util/parts/init.sh all || true

ci_announce "Sourcing env (II)..."
unset SCRIPTPATH ci_env_ sh_env_ sh_util_ ci_util_
. "${BASH_ENV:="$CWD/tools/ci/env.sh"}"

close_stage
