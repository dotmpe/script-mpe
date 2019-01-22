#!/usr/bin/env bash

test -n "${LOG:-}" -a -x "${LOG:-}" -o \
  "$(type -t "${LOG:-}" 2>/dev/null )" = "function" &&
  LOG_ENV=1 INIT_LOG=$LOG || LOG_ENV=0 INIT_LOG=$U_S/tools/sh/log.sh

# Sync: U-S:
