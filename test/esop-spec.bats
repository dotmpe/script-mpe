#!/usr/bin/env bats

load init
base=esop.sh

init


@test "${bin} - No arguments: default action is ..." {
  export verbosity=4
  run $bin
  { test $status -eq 1 &&
    test_nok_nonempty "*esop*No command given*"
  }|| stdfail 1

  run /bin/bash "$bin"
  {
    test_nok_nonempty "*esop*Error:*please use sh, or bash -o 'posix'*" &&
    test ${status} -eq 5
  } || stdfail 2

  run /bin/sh "$bin"
  {
    test_nok_nonempty "*esop*No command given*" "${lines[*]}" &&
    test ${status} -eq 1
  } || stdfail 3

  run bash "$bin"
  test ${status} -eq 5
}

@test ". ${bin}" {
  run sh -c "$BATS_TEST_DESCRIPTION"
  test ${status} -ne 0
  #fnmatch "esop:*not a frontend for sh" "${lines[*]}"

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  #fnmatch "esop:*not a frontend for bats-exec-test" "${lines[*]}"
}

@test ". ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}

@test "source ${bin}" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  #fnmatch "esop:*not a frontend for bats-exec-test" "${lines[*]}"
  run bash -c "$BATS_TEST_DESCRIPTION"
  test ${status} -ne 0
  #fnmatch "esop:*not a frontend for bash" "${lines[*]}"
}

@test "source ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}


@test "${bin} version" {
  source esop.sh load-ext
  base=esop

  run try_value version man_1
  test_ok_nonempty "Version info" || stdfail 1

  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail 2
}

@test "${bin} -vv -n help" {
  TODO "FIXME: subcmd alias"
  export verbosity=5 # Go to level 7 with -vv
  run $BATS_TEST_DESCRIPTION
  test_ok_lines "*DRY-RUN*" "*esop loaded*" \
    "*try-exec-func 'esop_load'*" \
    "*cmd=esop args=" \
    "*subcmd=help subcmd_alias= subcmd_def=" \
    || stdfail
}
