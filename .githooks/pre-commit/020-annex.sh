#!/usr/bin/env bash
test ${SHLVL:-0} -le ${lib_lvl:-0} && status=return || { lib_lvl=$SHLVL && set -euo pipefail -o posix && status=exit ; } # Inherit shell or init new

test -z "${scm_nok:-}" || $status $scm_nok

: "${LOG:="/srv/project-local/user-scripts/tools/sh/log.sh"}"
test -x "${LOG:-}" || exit 103

set -euo pipefail -o posix

: "${PROJECT_BASE:="`git rev-parse --show-toplevel`"}"


# GIT Annex hooks

test ! -d $PROJECT_BASE/.git/annex || $status

git annex pre-commit . ||
  $LOG error "" "GIT Annex pre-commit hook failed" $? 1

# Sync: U-S:
