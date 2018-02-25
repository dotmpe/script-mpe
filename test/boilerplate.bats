#!/usr/bin/env bats

base=boilerplate
load init
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

#@test "${lib}/${base} - function should ..." {
#  check_skipped_envs || \
#    TODO "envs $envs: implement lib (test) for env" # tasks-ignore
#  diag
#  run function args
#  test true || fail
#  test_ok_empty || stdfail
#  test_ok_nonempty || stdfail
#  test_ok_nonempty "*match*" || stdfail
#  { test_nok_nonempty "*match*" &&
#    test ${status} -eq 1 &&
#    fnmatch "*other*" &&
#    test ${#lines[@]} -eq 3
#  } || stdfail
#}
