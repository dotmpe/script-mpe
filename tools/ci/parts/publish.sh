#!/bin/sh
# Publish build-report to CouchDB

dig +short myip.opendns.com @resolver1.opendns.com || true

curl -sSf https://$CI_DB_HOST/ || {
  echo "No remote DB, skipped publish" >&2
  exit 0
}

cat $TEST_RESULTS-1.tap | tap-json > $TEST_RESULTS-1.json

not_falseish "$SHIPPABLE" && {
  tap2junit $TEST_RESULTS-1.tap $TEST_RESULTS-2.xml
}

wc -l $TEST_RESULTS*
cp $TEST_RESULTS-1.json $TEST_RESULTS.json


  CI_BUILD_ENV="$PARAMS.json" \
  CI_BUILD_RESULTS=$TEST_RESULTS.json \
  CI_DB_HOST="$CI_DB_HOST" \
  CI_DB_INFO="$CI_DB_INFO" \
  CI_DB_NAME='build-log' \
      node ./tools/update-couchdb-testlog.js || {

      echo "Ignored publisher failure" >&2
      sleep 2
      exit 0
    }

# Id: script-mpe/0.0.4-dev tools/ci/parts/publish.sh
