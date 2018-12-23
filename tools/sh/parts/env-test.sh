#!/bin/ash


: "${default_lib:="main"}"
: "${testpath:="`pwd -P`/test"}"

test -n "$BATS_LIB_PATH" || {
  BATS_LIB_PATH=$BATS_CWD/test:$BATS_CWD/test/helper:$BATS_TEST_DIRNAME
}

# XXX: relative path to templates/fixtures?
SHT_PWD="$( cd $BATS_CWD && realpath $BATS_TEST_DIRNAME )"
#SHT_PWD="$(grealpath --relative-to=$BATS_CWD $BATS_TEST_DIRNAME )"

# hostname-init()
hostnameid="$(hostname -s | tr 'A-Z.-' 'a-z__')"

# XXX scriptpath in test-env?
#scriptpath=$PWD/src/sh/lib
#SCRIPTPATH=$PWD/src/sh/lib:$HOME/bin

#util_mode=load-ext . $scriptpath/tools/sh/init.sh
# util_mode=load-ext . $scriptpath/util.sh

#export ENV=./tools/sh/env.sh
export ENV_NAME=testing
export TEST_ENV=bats
