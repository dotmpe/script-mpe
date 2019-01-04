#!/usr/bin/env bash
# See .travis.yml

set -u
export_stage failure && announce_stage

close_stage
set +u
