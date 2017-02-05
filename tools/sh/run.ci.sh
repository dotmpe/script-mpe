
# CI run flow:

scriptname=ci-parts:init
. $scriptdir/tools/ci/parts/init.sh

scriptname=ci-parts:install
. $scriptdir/tools/ci/parts/install.sh

scriptname=ci-parts:check
. $scriptdir/tools/ci/parts/check.sh

scriptname=ci-parts:build
. $scriptdir/tools/ci/parts/build.sh

