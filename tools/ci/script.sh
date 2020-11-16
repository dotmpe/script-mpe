#!/usr/bin/env bash

# CI suite stage 4.

export_stage script && announce_stage

$LOG note "" "Running main steps" "$(suite_from_table "${build_txt}" Parts $SUITE 4 | tr '\n' ';')"
sh_include start
suite_run "${build_txt}" $SUITE 4
sh_include finish

close_stage && ci_announce "Done"
return $fail_cnt
# Sync: U-S:
