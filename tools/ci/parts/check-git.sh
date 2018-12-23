#!/bin/sh
echo '---------- Check for sane GIT state'

GIT_COMMIT="$(git rev-parse HEAD)"
test "$GIT_COMMIT" = "$TRAVIS_COMMIT" || {

  # For Sanity: Travis won't complain if you accidentally
  # cache the checkout, but this should:
  git reset --hard $TRAVIS_COMMIT || {
    echo '---------- git reset:'
    env | grep -i Travis
    git status
    $LOG error ci:build "Unexpected checkout $GIT_COMMIT" "" 1
    return 1
  }
}
