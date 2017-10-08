#!/usr/bin/env bats

base=meta-sh.sh
load helper
init
#pwd=$(cd .;pwd -P)


version=0.0.4-dev # script-mpe

#setup() {
#  scriptname=test-$base
#  . $ENV
#}

@test "$bin no arguments no-op prints usage" {
  verbosity=5 run $bin
  { test $status -eq 1 &&
    test ${#lines[@]} -gt 3
  } || stdfail
}

@test "$bin -h" "Lists commands" {
  run $BATS_TEST_DESCRIPTION
  { test $status -ne 0 &&
    # Output must at least be usage lines + nr of functions (12)
    test "${#lines[@]}" -gt 8
  } || stdfail
}


