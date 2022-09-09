#!/usr/bin/env bash
test ${SHLVL:-0} -le ${lib_lvl:-0} && status=return || { lib_lvl=$SHLVL && set -euo pipefail -o posix && status=exit ; } # Inherit shell or init new

test -z "${scm_nok:-}" || $status $scm_nok

: "${LOG:="/srv/project-local/user-scripts/tools/sh/log.sh"}"
test -x "${LOG:-}" || exit 103

set -euo pipefail -o posix

: "${PROJECT_BASE:="`git rev-parse --show-toplevel`"}"

test \
    -e ${PROJECT_BASE}/.version-attributes \
    -o -e ${PROJECT_BASE}/.versioned-files.list && {

  git-versioning check &&
    $LOG note "OK" "Git-version checked" ||
    $LOG warn "Not OK" "Git versioning check failed" "$?" 1
}

# Sync: U-S:
