#!/usr/bin/env bats

load helper
base=dckr

init_bin


@test "$bin rewrite and test to new main.sh" {

  check_skipped_envs || \
    skip "TODO envs $envs: implement bin for env"
  #run $BATS_TEST_DESCRIPTION
  #test $status -eq 0
  #test "${#lines[@]}" = "9"
  #test -z "${lines[*]}" # empty output
}

# vim:et:ft=sh:
