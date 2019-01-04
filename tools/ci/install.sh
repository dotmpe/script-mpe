#!/bin/sh

export_stage install && announce_stage

# XXX: Call for dev setup, see +U_s
#$script_util/parts/init.sh all

ci_announce "Sourcing env (II)..."
unset SCRIPTPATH ci_env_ sh_env_ sh_util_ ci_util_
. "${ci_util}/env.sh"
#. "${BASH_ENV:="$CWD/tools/ci/env.sh"}"

close_stage

. "$ci_util/deinit.sh"
