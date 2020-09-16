#!/usr/bin/env bash

ci_announce 'Initializing for build-stats and statusdir-cache'

ci_announce "Logging into docker hub '$DOCKER_USERNAME'"
# NOTE: use stdin to prevent user re-prompt; but cancel build on failure
echo "$DOCKER_PASSWORD" | \
  ${dckr_pref-}docker login --username $DOCKER_USERNAME --password-stdin || exit $?

mkdir -p ~/.statusdir/{log,tree,index}

sh_include env-docker-cache

# NOTE: U-S update later is too late for init-docker-cache @Dev
if test -z "${TRAVIS-}"
then lib_require u_s-dckr u_s-ledge
else
  ( cd $U_S && git pull origin $(git rev-parse --abbrev-ref HEAD) )
  # XXX: SCRIPTPATH=$SCRIPTPATH:$CWD/commands
  lib_reload u_s-dckr u_s-ledge
fi

ci_announce "Looking for image at hub..."
ledge_exists && {
  ci_announce "Found image, extracting build log."
  ledge_refreshlogs || return

  ci_announce 'Retrieved logs'
}

test -s "$builds_log" && {
  ci_announce "Existing builds log found, last three logs (of $(wc -l "$builds_log"|awk '{print $1}')) where:"
  ledge_lastbuilds
} ||
  ci_announce "No existing builds log found"

# TODO: gather results into log uid:Jn7E
test -s "$results_log" && {
  ci_announce "Existing results log found; last three logs (of $(wc -l "$results_log"|awk '{print $1}')) where:"
  read_nix_style_file "$results_log" | tail -n 3
} ||
  ci_announce "No existing results log found"

# Add new build-announce log line
printf '%s %s %s %s %s %s\n' "$TRAVIS_TIMER_START_TIME" \
 "$TRAVIS_JOB_ID" \
 "$TRAVIS_JOB_NUMBER" \
 "$TRAVIS_BRANCH" \
 "$COMMIT_RANGE" \
 "$TRAVIS_BUILD_ID" >>"$builds_log"
ci_announce 'New builds log:'
tail -n 1 "$builds_log"
wc -l "$builds_log" || true

test ${announce:-0} -eq 0 || {

  ledge_pushlogs
}
# Sync: U-S:
