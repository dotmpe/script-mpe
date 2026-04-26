#!/usr/bin/env bash

# FIXME:
VND_SRC_PREFIX=${VND_SRC_PREFIX%%:*}
#source $VND_SRC_PREFIX/mbland/go-script-bash/lib/bats/assertions

source $VND_SRC_PREFIX/ztombol/bats-support/load.bash
source $VND_SRC_PREFIX/ztombol/bats-assert/load.bash
source $VND_SRC_PREFIX/ztombol/bats-file/load.bash

# Sync: U-S:test/helper/assert.bash
