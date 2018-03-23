#!/usr/bin/env bats

base=boilerplate
load init
init
#init_bin


@test "$base -vv -n help" {
  skip "some reason to skip test"
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}

@test "${base} - function should ..." {
  TODO fix this or that # tasks-ignore
  run function args
  test_ok_nonempty || stdfail
}

@test "${base} - should succeed" {
  run true
  test_ok_empty || stdfail
}

@test "${base} - should fail" {
  run false
  test_ok_empty || stdfail
}

#@test "${lib}/${base} - function should ..." {
#  check_skipped_envs || \
#    TODO "envs $envs: implement lib (test) for env" # tasks-ignore
#  diag $BATS_TEST_DESCRIPTION
#  run function args
#  test true && pass || fail
#  test_ok_empty || stdfail
#  test_nok_empty || stdfail
#  test_nonempty || stdfail
#  test_ok_nonempty "*match*" || stdfail
#  { test_nok_nonempty "*match*" &&
#    test ${status} -eq 1 &&
#    fnmatch "*other*" &&
#    test ${#lines[@]} -eq 3
#  } || stdfail
#  test_lines, test_ok_lines, test_nok_lines
#}
