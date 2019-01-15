#!/bin/sh

test -n "$LOG" && LOG_ENV=1 || LOG_ENV=
test -n "$LOG" -a -x "$LOG" -o "$(type -f "$LOG" 2>/dev/null )" = "function" &&
  INIT_LOG=$LOG || INIT_LOG=$CWD/tools/sh/log.sh

# Sync: user-scripts/ tools/sh/parts/env-init-log.sh :vim:ft=sh:
