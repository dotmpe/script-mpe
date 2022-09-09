#!/usr/bin/env bash

# CI suite stage 6a.

export_stage success && announce_stage

export BUILD_STATUS=success
sh_include publish

close_stage
# Sync: U-S:
