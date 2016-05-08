#!/usr/bin/env bats

load helper
base=esop.sh

init

source $lib/util.sh
source $lib/std.lib.sh
source $lib/str.lib.sh

#  echo "${lines[*]}" > /tmp/1
#  echo "${status}" >> /tmp/1

@test "${bin}" "No arguments: default action is ..." {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "esop*No command given*" "${lines[*]}"

  test -n "$SHELL"
  run $SHELL "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 5
  fnmatch "*esop*Error:*please use sh, or bash -o 'posix'*" "${lines[*]}"

  run sh "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 1
  fnmatch "esop*No command given*" "${lines[*]}"

  run bash "$BATS_TEST_DESCRIPTION"
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
  test ${status} -eq 0
  test "${lines[*]}" = "Version info"
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
#  #echo ${status} > /tmp/1
#  #echo "${lines[*]}" >> /tmp/1
#  #echo "${#lines[@]}" >> /tmp/1
#  test ${status} -eq 0
#}

