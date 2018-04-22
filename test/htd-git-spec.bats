#!/usr/bin/env bats

load init


@test "htd git - help" {
  run htd help git
  test_ok_nonempty || stdfail
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
