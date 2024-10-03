#!/bin/sh

# Sanity check that Travis-Commit matches actual checkout to catch setup fail

ci_announce 'Checking for sane GIT state'

# TODO: fetching tags is no use if checked out with --depth and no
# rechable tags are available. Should check that tags don't threaten to
# go beyond some threshold.

# XXX: CI: git fetch origin --tags --quiet

GIT_DESCRIBE="$(git describe --always)"
$INIT_LOG header2 "GIT version" "$GIT_DESCRIBE"

test "$(whoami)" != "travis" || {
  test "$GIT_COMMIT" = "$TRAVIS_COMMIT" || {

    # For Sanity: Travis won't complain if you accidentally
    # cache the checkout, but this should:
    git reset --hard $TRAVIS_COMMIT || {
      ci_announce 'Git reset:'
      git status
      $LOG error ci:build "Unexpected checkout $GIT_COMMIT" "" 1
      return 1
    }
  }
}
# Sync: U-S:
