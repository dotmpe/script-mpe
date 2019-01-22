#!/usr/bin/env bash

# Parse tags from commit message to influence build flow

: "${GIT_COMMIT:=$(git rev-parse HEAD)}"
: "${GIT_COMMIT_MSG:="$(git log -n 1 --format=%B "$GIT_COMMIT" )"}"
: "${GIT_COMMIT_LINE:="$(git log -n 1 --oneline --format=%B "$GIT_COMMIT" )"}"


ci_check "Commit is signed" \
    fnmatch "*Signed-off-by:*" "$GIT_COMMIT_MSG"

ci_check "Commit merge conflicts" \
    fnmatch "*Conflicts:*" "$GIT_COMMIT_MSG"


# Look for []-bounded, ,-separated tags in string

ci_check "Skip CI" \
    ci_tags "$GIT_COMMIT_MSG" "ci skip" "skip ci" \
        "skip travis" "travis skip"

ci_check "Skip build" \
    ci_tags "$GIT_COMMIT_MSG" "no script" "skip script" \
        "skip script" "no build"

ci_check "Skip test" \
    ci_tags "$GIT_COMMIT_MSG" "no test" "skip test" "skip test"

ci_check "Build Pre-init Cache Clear" \
    ci_tags "$GIT_COMMIT_MSG" "clear cache" "cache clear"


# Sync: U-S:
