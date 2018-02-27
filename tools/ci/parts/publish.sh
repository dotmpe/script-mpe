#!/bin/sh
# Publish build-report to CouchDB
set -e
dig +short myip.opendns.com @resolver1.opendns.com || true
curl -s https://4.ifcfg.me/
curl -s http://whatismyip.akamai.com/
curl -sSf https://$CI_DB_HOST/ || {
  echo "No remote DB, skipped publish" >&2
  exit 0
}
cat $TEST_RESULTS | tap-json > $TEST_RESULTS.json
PARAMS=/tmp/htd-ci-publish-build-params-$(uuidgen)
build_params > $PARAMS.env
any-json --input-format=ini $PARAMS.env $PARAMS.json
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
