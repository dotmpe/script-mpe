#!/usr/bin/env bash

# CI suite stage 5.

export_stage before-cache before_cache && announce_stage

test -z "${TRAVIS-}" ||
  sh_include travis-before-cache

close_stage
# Sync: U-S:
