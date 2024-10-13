#!/bin/sh

# CI run flow:

scriptname=ci-parts:init
. $scriptpath/tool/ci/part/init.sh

scriptname=ci-parts:install
. $scriptpath/tool/ci/part/install.sh

scriptname=ci-parts:check
. $scriptpath/tool/ci/part/check.sh

scriptname=ci-parts:build
. $scriptpath/tool/ci/part/build.sh

# Sync: U-S:
