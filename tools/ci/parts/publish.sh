#!/bin/sh
# Pub/dist

# XXX: export publish_ts=$(epoch_microtime)
export publish_ts=$($gdate +%s.%N)
ci_stages="$ci_stages publish"

ci_announce "Starting ci:publish"


. "./tools/ci/parts/report-times.sh"

# FIXME: pubish

#echo "WAN IP: $(wanip)" || true
#
#tap-json \
#    < $TEST_RESULTS-1.tap \
#    > $TEST_RESULTS-1.json
#
#test "$SHIPPABLE" = true && {
#  tap2junit $TEST_RESULTS-1.tap $TEST_RESULTS-2.xml
#} || true
#
#wc -l $TEST_RESULTS*
#
#cp $TEST_RESULTS-1.json $TEST_RESULTS.json
#
#  CI_BUILD_ENV="$PARAMS.json" \
#  CI_BUILD_RESULTS=$TEST_RESULTS.json \
#  CI_DB_HOST="$CI_DB_HOST" \
#  CI_DB_INFO="$CI_DB_INFO" \
#  CI_DB_NAME='build-log' \
#      node ./tools/update-couchdb-testlog.js || {
#
#      echo "Ignored publisher failure" >&2
#      sleep 2
#      return 0
#    }

# Id: script-mpe/0.0.4-dev tools/ci/parts/publish.sh
