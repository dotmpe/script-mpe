#!/usr/bin/env bats

load helper
base=esop.sh

init


@test "${bin} - No arguments: default action is ..." {
  run $bin
  test ${status} -eq 1
  fnmatch "*esop*No command given*" "${lines[*]}" ||
    fail "1 Out: ${lines[*]}"

  run /bin/bash "$bin"
  fnmatch "*esop*Error:*please use sh, or bash -o 'posix'*" "${lines[*]}" ||
    fail "2 Out: ${lines[*]}"
  test ${status} -eq 5 || fail "2 Out($status): ${lines[*]}"

  run /bin/sh "$bin"
  test ${status} -eq 1 || fail "3.1 Out: ${lines[*]}"
  fnmatch "*esop*No command given*" "${lines[*]}" ||
    fail "3.2 Out($status): ${lines[*]}"

  run bash "$bin"
  test ${status} -eq 5
}

@test ". ${bin}" {
  run sh -c "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 1
  fnmatch "esop:*not a frontend for sh" "${lines[*]}"

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "esop:*not a frontend for bats-exec-test" "${lines[*]}"
}

@test ". ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
}

@test "source ${bin}" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "esop:*not a frontend for bats-exec-test" "${lines[*]}"
  run bash -c "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 1
  fnmatch "esop:*not a frontend for bash" "${lines[*]}"
}

@test "source ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
}


@test "${bin} version" {
  source esop.sh load-ext
  base=esop

  run try_value version man_1
  test ${status} -eq 0 \
    || fail "try_value version man_1: ${status}, out: ${lines[*]}"
  test "${lines[*]}" = "Version info" \
    || fail "try_value version man_1: ${status}, out: ${lines[*]}"
  test ! -z "${lines[*]}" # non-empty output

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
}

@test "${bin} -vv -n help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
  test ${#lines[@]} -gt 4  # lines of output (stdout+stderr)
}

#@test "${lib}/${base} - function should ..." {
#  check_skipped_envs || \
#    TODO "envs $envs: implement lib (test) for env"
#  run function args
#  { test_ok_nonempty && fnmatch "* ... * " "${lines[*]}" ; } || stdfail
#  { test_ok_empty ; } || stdfail
#  test ${status} -eq 0
#}
