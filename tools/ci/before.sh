#!/usr/bin/env bash
# See .travis.yml

set -u
export_stage before-script before_script && announce_stage

. "./tools/ci/parts/check.sh"

. "./tools/ci/parts/init-build-cache.sh"

close_stage
set +u
