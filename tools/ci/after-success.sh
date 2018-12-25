#!/bin/sh
export_stage success && announce_stage

close_stage
. "$ci_util/deinit.sh"
