#!/usr/bin/env bash
# CI suite stage 7. See .travis.yml
set -eu
export_stage after && announce_stage

sh_include publish

stage_id=after close_stage
set +eu
# Sync: U-S:
