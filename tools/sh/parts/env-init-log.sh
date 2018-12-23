#!/bin/sh

test -n "$LOG" && LOG_ENV=1 || LOG_ENV=
test -n "$LOG" -a -x "$LOG" && INIT_LOG=$LOG || INIT_LOG=$PWD/tools/sh/log.sh
