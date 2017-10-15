#!/bin/sh
# Publish TAP test-results file to CouchDB
set -e
test -x "$(which tap-json)" || npm install -g tap-json
cat $TEST_RESULTS | tap-json > $TEST_RESULTS.json
test -e node_modules/nano || npm install nano
CI_BUILD_RESULTS=$TEST_RESULTS.json \
  CI_DB_HOST="$CI_DB_HOST" \
  CI_DB_INFO="$CI_DB_INFO" \
  CI_DB_NAME='build-log' \
      node ./tools/update-couchdb-testlog.js
