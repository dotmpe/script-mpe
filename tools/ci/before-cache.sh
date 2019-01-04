#!/usr/bin/env bash
# See .travis.yml

set -u
export_stage before-cache before_cache && announce_stage
. "./tools/ci/parts/before-cache.sh"

close_stage
set +u
