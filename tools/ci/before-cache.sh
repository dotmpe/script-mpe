#!/bin/sh

export_stage before-cache before_cache && announce_stage
. "./tools/ci/parts/before-cache.sh"

close_stage
. "$ci_util/deinit.sh"
