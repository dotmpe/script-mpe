#!/usr/bin/env bash

export VND_SRC_PREFIX=$HOME/build
: "${CWD:="$PWD"}"

./sh-main sh-baseline.tab '*'

echo "Sourcing env (I)... <${BASH_ENV:-} $CWD $PWD>"
: "${ci_util:="$CWD/tools/ci"}"
. "${BASH_ENV:="$PWD/tools/ci/env.sh"}" || echo "Ignored: ERR:$?"

export_stage before-install before_install


. "$ci_util/parts/announce.sh"

# Get checkouts, tool installs and rebuild env (PATH etc.)
. "$ci_util/parts/init-user-repo.sh"


. "$ci_util/parts/check-git.sh"

. "$ci_util/parts/init.sh"

close_stage

. "$ci_util/deinit.sh"
# Id: script-mpe/0.0.4-dev tools/ci/before-install.sh
