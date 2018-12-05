#!/bin/sh
# Announce build-start asap for listeners

export travis_ci_timer_ts=$(echo "$TRAVIS_TIMER_START_TIME"|sed 's/\([0-9]\{9\}\)$/.\1/')

export ci_announce_ts=$($gdate +"%s.%N")

curl -sSf --connect-timeout 5 --max-time 15 https://$CI_DB_HOST/ || {
  $LOG warn "$scriptname" "No remote DB, skipped build-log announce" >&2
  return 0
}
$LOG error "$scriptname" "TODO: announce travis build" >&2

# CouchDB build-log record
#node --version
# FIXME: nodejs deps needed, use something that runs more directly; curl

#  CI_DB_HOST="$CI_DB_HOST" \
#  CI_DB_INFO="$CI_DB_INFO" \
#  CI_DB_NAME='build-log' \
#      node ./tools/update-couchdb-testlog.js || {
#
#      echo "Ignored announcer failure" >&2
#      sleep 2
#      return 0
#    }

# Id: script-mpe/0.0.4-dev tools/ci/parts/announce.sh
