
# CI run flow:
scriptname=ci-parts:init
. ./parts/init.sh
scriptname=ci-parts:install
. ./parts/install.sh
scriptname=ci-parts:check
. ./parts/check.sh
scriptname=ci-parts:build
. ./parts/build.sh

