#!/usr/bin/env bats

load init
base=box-instance.sh

init

source $lib/util.sh


@test "${bin}" "No arguments: default action is ..." {
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 1 &&
    fnmatch *"box-instance"*"No command given"* "${lines[*]}"
  } || stdfail 1

  test -n "$SHELL" || fail "SHELL env expected"
  run $SHELL "$BATS_TEST_DESCRIPTION"
  { test ${status} -eq 5 &&
    fnmatch *"box-instance"*"Error"*"please use sh, or bash -o 'posix'"* "${lines[*]}"
  } || stdfail 2

  run sh "$BATS_TEST_DESCRIPTION"
  { test ${status} -eq 1 &&
    fnmatch "*box-instance*No command given*" "${lines[*]}"
  } || stdfail 3

  run bash "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 5 || stdfail 4
}

@test ". ${bin}" {
  run sh -c "$BATS_TEST_DESCRIPTION"
  { test ${status} -eq 1 &&
    fnmatch "box-instance:*not a frontend for sh" "${lines[*]}"
  } || stdfail

  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 1 &&
    fnmatch "box-instance:*not a frontend for bats-exec-test" "${lines[*]}"
  } || stdfail
}

@test ". ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}

@test "source ${bin}" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "box-instance:*not a frontend for bats-exec-test" "${lines[*]}"
  run bash -c "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 1
  fnmatch "box-instance:*not a frontend for bash" "${lines[*]}"
}

@test "source ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}

@test "${bin} x" {
  run $BATS_TEST_DESCRIPTION
  { test ${status} -ne 0 &&
    fnmatch "*box-instance.*:*x*Error*Arguments expected*" "${lines[*]}"
  } || stdfail
}

@test "${bin} x foo bar" {
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
    fnmatch "*box-instance.*:*x*Running X*" "${lines[*]}"
  } || stdfail
}

@test "${bin} x arg spec" {

  source ./box-instance.sh load-ext
  base=box-instance

  run try_value x spc
  { test ${status} -eq 0 &&
    test "${lines[*]}" = "x ARG [ARG..]"
  } || stdfail

  run try_value x man_1
  { test ${status} -eq 0 &&
    test "${lines[*]}" = "abc"
  } || stdfail
}

@test "${bin} y" {
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
    fnmatch "*box-instance.*:*y*Running Y*" "${lines[*]}"
  } || stdfail
}

@test "${bin} help x " {
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
    fnmatch "*Usage:*" "${lines[*]}" &&
    fnmatch "*x*abc*" "${lines[*]}"
  } || stdfail
}

@test "${bin} help y " {
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
    fnmatch "*no help*'y'*" "${lines[*]}"
  } || stdfail
}

@test "${bin} -vv -n help" {
  #skip "envs: envs=$envs FIXME is hardcoded in test/helper.bash current_test_env"
  #check_skipped_envs || TODO "envs $envs: implement bin (test) for env"
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
    test ${#lines[@]} -gt 4  # lines of output (stdout+stderr)
  } || stdfail
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
