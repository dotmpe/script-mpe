#!/bin/sh

export scriptname=after-script after_script_ts="$(date +"%s.%N")"

export ci_after_ts=$($gdate +"%s.%N")

note 'Travis test-result: '"$TRAVIS_TEST_RESULT"

. ./tools/ci/parts/after.sh
. ./tools/ci/parts/publish.sh
std_note "End of $scriptname"

echo done
