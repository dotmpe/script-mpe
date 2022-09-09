#!/usr/bin/env bash
test ${SHLVL:-0} -le ${lib_lvl:-0} && status=return || { lib_lvl=$SHLVL && set -euo pipefail -o posix && status=exit ; } # Inherit shell or init new

test -z "${scm_nok:-}" || $status $scm_nok
#test 1 -eq "${quiet:-0}" || ...
# Sync: U-S:
