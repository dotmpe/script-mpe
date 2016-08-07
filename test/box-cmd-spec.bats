#!/usr/bin/env bats

load helper
base=box-instance

init

source $lib/util.sh
source $lib/std.lib.sh
source $lib/str.lib.sh

#  echo "${lines[*]}" > /tmp/1
#  echo "${status}" >> /tmp/1

@test "${bin}" "No arguments: default action is ..." {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "box-instance*No command given*" "${lines[*]}"

  test -n "$SHELL"
  run $SHELL "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 5
  fnmatch "*box-instance*Error:*please use sh, or bash -o 'posix'*" "${lines[*]}"

  run sh "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 1
  fnmatch "box-instance*No command given*" "${lines[*]}"

  run bash "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 5
}

@test ". ${bin}" {
  run sh -c "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 1
  fnmatch "box-instance:*not a frontend for sh" "${lines[*]}"

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "box-instance:*not a frontend for bats-exec-test" "${lines[*]}"
}

@test ". ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
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
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
}

@test "${bin} x" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -ne 0
  test ! -z "${lines[*]}" # non-empty output
  fnmatch "*box-instance.*:*x*Error*Arguments expected*" "${lines[*]}"
}

@test "${bin} x foo bar" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ! -z "${lines[*]}" # non-empty output
  fnmatch "*box-instance.*:*x*Running X*" "${lines[*]}"
}

@test "${bin} x arg spec" {

  source box-instance load-ext
  base=box-instance

  run try_value x spc
  test ${status} -eq 0
  test "${lines[*]}" = "x ARG [ARG..]"
  test ! -z "${lines[*]}" # non-empty output

  run try_value x man_1
  test ${status} -eq 0
  test "${lines[*]}" = "abc"
}

@test "${bin} y" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ! -z "${lines[*]}" # non-empty output
  fnmatch "*box-instance.*:*y*Running Y*" "${lines[*]}"
}

@test "${bin} help x " {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0 || fail "$status Out: ${lines[*]}"
  test ! -z "${lines[*]}" # non-empty output
  fnmatch "*Usage:*" "${lines[*]}"
  fnmatch "*x*abc*" "${lines[*]}"
}

@test "${bin} help y " {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ! -z "${lines[*]}" # non-empty output
  fnmatch "*Usage:*" "${lines[*]}"
}

@test "${bin} -vv -n help" {
  #skip "envs: envs=$envs FIXME is hardcoded in test/helper.bash current_test_env"
  #check_skipped_envs || TODO "envs $envs: implement bin (test) for env"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
  test ${#lines[@]} -gt 4  # lines of output (stdout+stderr)
}

#@test "${lib}/${base} - function should ..." {
#  check_skipped_envs || \
#    TODO "envs $envs: implement lib (test) for env"
#  run function args
#  #echo ${status} > /tmp/1
#  #echo "${lines[*]}" >> /tmp/1
#  #echo "${#lines[@]}" >> /tmp/1
#  test ${status} -eq 0
#}


