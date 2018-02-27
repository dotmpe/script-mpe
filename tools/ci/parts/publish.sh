#!/bin/sh
# Publish TAP test-results file to CouchDB
set -xe
dig +short myip.opendns.com @resolver1.opendns.com || true
curl -sSf https://$CI_DB_HOST/ || {
  echo "No remote DB, skipped publish" >&2
  exit 0
}
cat $TEST_RESULTS | tap-json > $TEST_RESULTS.json
CI_BUILD_RESULTS=$TEST_RESULTS.json \
  CI_DB_HOST="$CI_DB_HOST" \
  CI_DB_INFO="$CI_DB_INFO" \
  CI_DB_NAME='build-log' \
      node ./tools/update-couchdb-testlog.js
# Id: script-mpe/0.0.4-dev tools/ci/parts/publish.sh
