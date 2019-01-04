#!/usr/bin/env bash

: "${default_lib:="main"}"
: "${testpath:="`pwd -P`/test"}"

# hostname-init()
hostnameid="$(hostname -s | tr 'A-Z.-' 'a-z__')"

#util_mode=load-ext . $scriptpath/tools/sh/init.sh
#util_mode=load-ext . $scriptpath/util.sh

#export ENV=./tools/sh/env.sh
export ENV_NAME=testing
export TEST_ENV=bats
