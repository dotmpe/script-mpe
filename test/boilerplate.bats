#!/usr/bin/env bats

base=boilerplate
load helper
init
#init_bin


@test "${bin} -vv -n help" {
  skip "reason"
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}

@test "${lib}/${base} - function should ..." {
  TODO something # tasks-ignore
  run function args
  test_ok_nonempty || stdfail
}

