#!/bin/sh
export_stage failure && announce_stage

close_stage
. "$ci_util/deinit.sh"
