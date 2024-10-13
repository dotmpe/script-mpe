#!/usr/bin/env bash
set -euo pipefail

: "${SUITE:="Main"}"
. ./tool/ci/env.sh

$LOG "info" "" "Started main env" "$_ENV"
# Sync: U-s
