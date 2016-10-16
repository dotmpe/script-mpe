#!/usr/bin/env bats

base=meta
load helper
init
#pwd=$(cd .;pwd -P)


version=0.0.2-dev # script-mpe

@test "$bin no arguments no-op prints usage" {
  run $bin
  test $status -eq 1
  # Usage output is 4 lines long
  test ${#lines[@]} -eq 4
}

@test "$bin help" "Lists commands" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  # Output must at least be usage lines + nr of functions
  test "${#lines[@]}" -gt 8
}


