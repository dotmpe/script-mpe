#!/usr/bin/env bash

test ${env_init_log_:-1} -eq 0 || {

  # Set LOG if we dont have either an executable script or function, and set
  # INIT_LOG from LOG
  test -n "${LOG:-}" -a -x "${LOG:-}" -o \
    "$(type -t "${LOG:-}" 2>/dev/null )" = "function" &&
      LOG_ENV=1 || LOG_ENV=0

  test $LOG_ENV -eq 1 && {
    test -n "${INIT_LOG-}" || INIT_LOG=$LOG
  } || {
    test -n "${INIT_LOG-}" || {

      # XXX: "auto-detect" LOG for use during INIT
      test -x "${ci_util}/log.sh" &&
          : "${INIT_LOG:="$ci_util/log.sh"}"
      test -x "${main_util}/log.sh" &&
          : "${INIT_LOG:="$main_util/log.sh"}"
      test -x "${sh_util}/log.sh" &&
          : "${INIT_LOG:="$sh_util/log.sh"}"

      test -x "${script_util}/log.sh" &&
          : "${INIT_LOG:="$script_util/log.sh"}"
      test -x "${CWD}/tools/sh/log.sh" &&
          : "${INIT_LOG:="$CWD/tools/sh/log.sh"}"
      test -x "${U_S-}/tools/sh/log.sh" &&
          : "${INIT_LOG:="$U_S/tools/sh/log.sh"}"
    }
  }

  env_init_log_=0
  $INIT_LOG debug "" "Init-LOG env started" "$LOG_ENV $INIT_LOG"
}
# Sync: U-S:
