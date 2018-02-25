#!/usr/bin/env bats

base=meta-sh.sh
load init
init


@test "$bin no arguments no-op prints usage" {
  verbosity=5 run $bin
  { test $status -eq 1 &&
    test ${#lines[@]} -gt 3
  } || stdfail
}

@test "$bin -h" "Lists commands" {
  run $BATS_TEST_DESCRIPTION
  { test $status -eq 0 &&
    # Output must at least be usage lines + nr of functions (12)
    test ${#lines[@]} -gt 8
  } || stdfail
}
