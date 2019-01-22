#!/usr/bin/env bash
# CI suite stage 6b. See .travis.yml
set -eu
export_stage failure && announce_stage

close_stage
set +eu
# Sync: U-S:
