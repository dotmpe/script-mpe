#!/usr/bin/env bats

load helper
base=esop.sh

init

source $lib/str.lib.sh

#  echo "${lines[*]}" > /tmp/1
#  echo "${status}" >> /tmp/1

@test ". ${bin}" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "*esop.*not a frontend for*" "${lines[*]}"
}

@test ". ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
}

@test "source ${bin}" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "*esop.*not a frontend for*" "${lines[*]}"
}

@test "source ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
}

@test "${bin} x" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ! -z "${lines[*]}" # non-empty output
  fnmatch "*esop.*:*x*Running x*" "${lines[*]}"
}

@test "${bin} arg spec" {
  source esop.sh load-ext
  base=esop

  run try_value x spc
  test ${status} -eq 0
  test "${lines[*]}" = "x [ARG..]"
  test ! -z "${lines[*]}" # non-empty output

  run try_value x man_1
  test ${status} -eq 0
  test "${lines[*]}" = "abc"
}

#@test "${bin} -vv -n help" {
#  skip "envs: envs=$envs FIXME is hardcoded in test/helper.bash current_test_env"
#  check_skipped_envs || skip "TODO envs $envs: implement bin (test) for env"
#  run $BATS_TEST_DESCRIPTION
#  test ${status} -eq 0
#  test -z "${lines[*]}" # empty output
#  test "${#lines[@]}" = "0" # lines of output (stdout+stderr)
#}

#@test "${lib}/${base} - function should ..." {
#  check_skipped_envs || \
#    skip "TODO envs $envs: implement lib (test) for env"
#  run function args
#  #echo ${status} > /tmp/1
#  #echo "${lines[*]}" >> /tmp/1
#  #echo "${#lines[@]}" >> /tmp/1
#  test ${status} -eq 0
#}

