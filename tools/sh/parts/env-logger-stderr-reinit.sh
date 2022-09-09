#!/usr/bin/env bash

: "${LOG:="$CWD/tools/sh/log.sh"}"

test -n "${LOG:-}" -a -x "${LOG:-}" -o \
  "$(type -t "${LOG:-}" 2>/dev/null )" = "function" || {

  type $LOG  2>/dev/null >&2 || {
    test "$LOG" = "logger_stderr" || return 102
    $CWD/tools/sh/log.sh info "sh:env" "Reloading existing logger env"

    type lib_load >/dev/null 2>&1 || {
      . $sh_tools/init.sh || return
    }
    lib_load logger logger-theme logger-std || return
  }
}

export LOG
# Sync: U-S:
