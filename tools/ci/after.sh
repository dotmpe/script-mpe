#!/usr/bin/env bash
# See .travis.yml

set -u
export_stage after && announce_stage

echo 'Travis test-result: '"$TRAVIS_TEST_RESULT"

. "./tools/ci/parts/publish.sh"

close_stage
set +u
