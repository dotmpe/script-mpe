#!/usr/bin/env bash

export VND_SRC_PREFIX=$HOME/build
: "${DEBUG:=""}"
: "${CWD:="$PWD"}"

set -o errexit
set -o pipefail


ci_cleanup()
{
  echo '------ Exited'
  sleep 2
  sync
}

trap ci_cleanup EXIT

: "${script_util:="$CWD/tools/sh"}"
: "${ci_util:="$CWD/tools/ci"}"
init_sh_boot=null

# Get checkouts, tool installs and rebuild env (PATH etc.)
$script_util/parts/init.sh init-dependencies dependencies.txt

echo "Sourcing env (I)... <${BASH_ENV:-} $CWD $PWD>" >&2
. "${ci_util}/env.sh" || echo "Ignored: ERR:$?" >&2

export_stage before-install before_install

. "$ci_util/parts/announce.sh"


test "$USER" = "travis" || sudo=sudo
${sudo} gem install travis

# Sanity check that Travis-Commit matches actual checkout to catch setup fail
. "$ci_util/parts/check-git.sh"

echo Starting baseline check >&2
scriptname=sh-main:baseline ./sh-main spec sh-baseline.tab '*' &&
  echo "Baseline check OK" >&2 || echo "Baseline check fail $?" >&2

# End with some settings and listings for current env.
. "$ci_util/parts/init-information.sh"

close_stage

. "$ci_util/deinit.sh"
# Id: script-mpe/0.0.4-dev tools/ci/before-install.sh
