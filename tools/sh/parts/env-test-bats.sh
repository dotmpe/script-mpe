#!/usr/bin/env bash

: "${BATS_VERSION:="v1.1.0"}"
: "${BATS_REPO:="https://github.com/bats-core/bats-core.git"}"
export BATS_VERSION BATS_REPO

: "${TMPDIR:="/tmp"}"
: "${BATS_CWD:="$CWD"}"
: "${BATS_TEST_DIRNAME:="$PWD/test"}"
#: "${BATS_TEST_DIRNAME:="$CWD"}"
: "${BATS_TMPDIR:="$TMPDIR/bats-temp-`uuidgen`"}"

# XXX: see test/init.bash parts
#test -n "${BATS_LIB_PATH:-}" || {
#  BATS_LIB_PATH=$BATS_CWD/test:$BATS_CWD/test/helper:$BATS_TEST_DIRNAME
#}

# XXX: relative path to templates/fixtures?
test -z "${BATS_TEST_DIRNAME:-}" ||
    SHT_PWD="$( cd $BATS_CWD && realpath $BATS_TEST_DIRNAME )"
#SHT_PWD="$(grealpath --relative-to=$BATS_CWD $BATS_TEST_DIRNAME )"
#
