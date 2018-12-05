#!/bin/sh

# CI run flow:

scriptname=ci-parts:init
. $scriptpath/tools/ci/parts/init.sh

scriptname=ci-parts:install
. $scriptpath/tools/ci/parts/install.sh

scriptname=ci-parts:check
. $scriptpath/tools/ci/parts/check.sh

scriptname=ci-parts:build
. $scriptpath/tools/ci/parts/build.sh
