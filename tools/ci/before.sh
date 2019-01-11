#!/usr/bin/env bash
# See .travis.yml

set -u
export_stage before-script before && announce_stage

. "./tools/ci/parts/check.sh"

. "./tools/ci/parts/init-build-cache.sh"

stage_id=before close_stage
set +u
