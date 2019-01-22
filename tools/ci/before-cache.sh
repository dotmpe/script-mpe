#!/usr/bin/env bash
# CI suite stage 5. See .travis.yml
set -u
export_stage before-cache before_cache && announce_stage

sh_include before-cache

close_stage
set +u
# Sync: U-S:
