#!/bin/sh
export ci_after_ts=$($gdate +"%s.%N")
note 'Travis test-result: '"$TRAVIS_TEST_RESULT"
