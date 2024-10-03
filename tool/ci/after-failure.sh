#!/usr/bin/env bash

# CI suite stage 6b.

export_stage failure && announce_stage

export BUILD_STATUS=failed
sh_include publish

close_stage
# Sync: U-S:
