#!/usr/bin/env bats

load helper
base=dckr

init_bin


@test "$bin rewrite and test to new main.sh" {
  check_skipped_envs $(hostname) || \
    skip "TODO $envs: implement for env $env: $BATS_TEST_DESCRIPTION"
  #run $BATS_TEST_DESCRIPTION
  #test $status -eq 0
  #test "${#lines[@]}" = "9"
  #test -z "${lines[*]}" # empty output
}

# vim:et:ft=sh:
