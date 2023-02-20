#!/usr/bin/env bash
set -euo pipefail

ci_announce 'Initializing for build-cache'

ci_announce "Logging into docker hub $DOCKER_USERNAME"
# NOTE: use stdin to prevent user re-prompt; but cancel build on failure
echo "$DOCKER_HUB_PASSWD" | \
  ${dckr_pref}docker login --username $DOCKER_USERNAME --password-stdin

mkdir -p "${STATUSDIR_ROOT:-$HOME/.local/statusdir/}"{log,tree,index}

: "${TRAVIS_REPO_SLUG:="$NS_NAME/user-scripts"}"
PROJ_LBL=$(basename "$TRAVIS_REPO_SLUG")
builds_log="${STATUSDIR_ROOT:-$HOME/.local/statusdir/}log/travis-$PROJ_LBL.list"
ledge_tag="$(printf %s "$PROJ_LBL-$TRAVIS_BRANCH" | tr -c 'A-Za-z0-9_-' '-')"

${dckr_pref}docker pull dotmpe/ledge:$ledge_tag && {

  ${dckr_pref}docker create --name ledge \
    -v ledge-statusdir:/statusdir \
    dotmpe/ledge:$ledge_tag

  test ! -e /tmp/builds.log || rm /tmp/builds.log
  test ! -e "$builds_log" || cp $builds_log /tmp/builds.log
  {
    test ! -e /tmp/builds.log || cat /tmp/builds.log

    ${dckr_pref}docker run -t --rm \
      --volumes-from ledge \
      busybox \
      sed 's/[\n\r]//g' /statusdir/log/travis-$PROJ_LBL.list

  } | $gsed 's/[\n\r]//g' | sort -u >$builds_log

  ${dckr_pref}docker rm -f ledge ; printf ' %s\n' "container removed"
  ${dckr_pref}docker volume rm ledge-statusdir ; printf ' %s\n' "volume removed"

  ci_announce 'Retrieved logs'
} || true

ci_announce 'Last log was'
tail -n 1 "$builds_log" || true
wc -l "$builds_log" || true

printf '%s %s %s %s %s\n' $TRAVIS_TIMER_START_TIME \
	$TRAVIS_JOB_ID \
	$TRAVIS_JOB_NUMBER \
	$TRAVIS_BRANCH \
	$TRAVIS_COMMIT_RANGE \
	$TRAVIS_BUILD_ID >>"$builds_log"
ci_announce 'New log'
tail -n 1 "$builds_log"
wc -l "$builds_log" || true

${dckr_pref}docker rmi -f dotmpe/ledge:$ledge_tag

cp test/docker/ledge/Dockerfile ~/.local/statusdir

${dckr_pref}docker build -qt dotmpe/ledge:$ledge_tag ~/.local/statusdir &&
  ${dckr_pref}docker push dotmpe/ledge:$ledge_tag

# Sync: U-S:
