#!/usr/bin/env bats

base=diskdoc.sh
load helper
init
#pwd=$(cd .;pwd -P)


version=0.0.0+20150911-0659 # script-mpe

@test "${bin}" "No arguments: default action is status" {
  test "$uname" != Darwin || skip Darwin
  run $bin
  test $status -eq 0
}

@test "$bin help" "Lists commands" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0 \
    || { diag "Output: ${lines[*]}"; fail "Status: ${status}"; }
  # Output must at least be usage lines + nr of functions
  test "${#lines[@]}" -gt 8
}

@test ". ${bin}" {
  run sh -c "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 1
  fnmatch "Not a frontend for sh*" "${lines[*]}"

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "Not a frontend for bats-exec-test*" "${lines[*]}"
}

@test ". ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
}

@test "source ${bin}" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "Not a frontend for bats-exec-test*" "${lines[*]}"
  run bash -c "$BATS_TEST_DESCRIPTION"
  test ${status} -eq 1
  fnmatch "Not a frontend for bash*" "${lines[*]}"
}

@test "source ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
}


@test "${bin} -vv -n help" {
  #skip "envs: envs=$envs FIXME is hardcoded in test/helper.bash current_test_env"
  #check_skipped_envs || TODO "envs $envs: implement bin (test) for env"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
  test ${#lines[@]} -gt 4  # lines of output (stdout+stderr)
}



