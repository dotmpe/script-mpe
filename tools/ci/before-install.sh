#!/bin/sh

. "${BASH_ENV:="$PWD/tools/ci/env.sh"}"


export_stage before-install before_install

# 'sponge' some scripts' output to try to prevent Travis from cutting of build;
# slow buffer?
# but sponged scripts cannot import local env or functions into build context.
#
# Would test sync as alternative but need more syntax either way..

. ./tools/ci/env.sh
. ./tools/ci/parts/init.sh
. ./tools/ci/parts/announce.sh
