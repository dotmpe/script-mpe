#!/bin/sh
note "Starting $scriptname..."
export ci_before_cache_ts=$(date +"%s.%N")

rm -f \
    $HOME/.cache/pip/log/debug.log \
    $HOME/.npm/anonymous-cli-metrics.json

std_note "End of $scriptname"
