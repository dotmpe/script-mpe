#!/bin/sh
export_stage after && announce_stage

# XXX- . ./tools/ci/parts/publish.sh

echo 'Travis test-result: '"$TRAVIS_TEST_RESULT"

announce "End of $scriptname"
echo Done
. $ci_util/deinit.sh
