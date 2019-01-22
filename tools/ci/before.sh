#!/usr/bin/env bash
# CI suite stage 3. See .travis.yml
set -u
export_stage before-script before && announce_stage

suite_run "${build_tab}" $SUITE 3

stage_id=before close_stage
set +u
# Sync: U-S:
