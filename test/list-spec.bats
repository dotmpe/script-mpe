#!/usr/bin/env bats

base=lst
load init
init


@test "${base} help" {

  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "${base} version" {

  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "${base} names scm" {

  export verbosity=0
  run $BATS_TEST_DESCRIPTION
  test_ok_lines .bzrignore .git/info/exclude .gitignore || stdfail
}

@test "${base} names local" {

  export verbosity=0
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}


#@test "${lib}/${base} - function should ..." {
#  check_skipped_envs || \
#    TODO "envs $envs: implement lib (test) for env" # tasks-ignore
#  diag $BATS_TEST_DESCRIPTION
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
