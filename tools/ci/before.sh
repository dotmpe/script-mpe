#!/bin/sh
export scriptname="before-script" before_script_ts="$(date +"%s.%N")"
note "Starting $scriptname..."
. ./tools/ci/parts/check.sh
