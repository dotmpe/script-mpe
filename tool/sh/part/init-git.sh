#!/usr/bin/env bash

# Travis remembers last-built commit, which in case of rewriting GIT history
# may not be the actual range really being build.

# Set a correct alternative to TRAVIS_COMMIT_RANGE

COMMIT_SHA1=$(git rev-parse HEAD)
COMMIT_SHA1_PREV=$(git rev-parse HEAD^)
export COMMIT_RANGE=${COMMIT_SHA1_PREV:0:12}...${COMMIT_SHA1:0:12}

# Sync: U-S:
