#!/usr/bin/env bash

: "${LOG:="$CWD/tools/sh/log.sh"}"

test -x "$LOG" -o "$(type -f "$LOG" 2>/dev/null )" = "function" || {
  type $LOG >&2 2>/dev/null || {
    test "$LOG" = "logger_stderr" || return 102
    $CWD/tools/sh/log.sh info "sh:env" "Reloaded existing logger env"

    . $script_util/init.sh
  }
}

export LOG
