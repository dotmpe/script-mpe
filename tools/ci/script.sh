#!/usr/bin/env bash
# CI suite stage 4. See .travis.yml
set -euo pipefail
export_stage script && announce_stage

$LOG note "" "Running main steps" "$(suite_from_table "${build_tab}" Parts $SUITE 4 | tr '\n' ';')"
sh_include start
suite_run "${build_tab}" $SUITE 4
sh_include finish

close_stage && ci_announce "Done"
set +euo pipefail
return $fail_cnt
# Sync: U-S:
