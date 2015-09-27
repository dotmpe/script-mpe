#!/usr/bin/env bats

load helper
base=./radical.py

init_lib
init_bin


@test "${bin} --help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
}
@test "${bin} -vv -h" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
}

@test "${bin} -q radical-test1.txt" {
  check_skipped_envs travis || \
    skip "TODO envs $envs: implement for env"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
}

@test "${bin} radical-test1.txt" {
  check_skipped_envs travis || \
    skip "TODO envs $envs: implement for env"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
  # 6 'note'-level log lines, three for issues: TODO: fix multiline scanning
  test "${#lines[@]}" = "6" # lines of output (stderr+stderr)
}

@test "${lib}/${base} - function should ..." {
  check_skipped_envs || \
    skip "TODO envs $envs: implement lib (test) for env"
  run function args
  #echo ${status} > /tmp/1
  #echo "${lines[*]}" >> /tmp/1
  #echo "${#lines[@]}" >> /tmp/1
  test ${status} -eq 0
}

