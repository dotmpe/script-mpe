#!/usr/bin/env bats

base=diskdoc.sh
load init
init


version=0.0.4-dev # script-mpe

@test "${bin}" "No arguments: default action is status" {
  check_skipped_envs travis || skip

  test "$uname" != Darwin || skip "Diskdoc env not available for BSD/Darwin"
  run $bin
  test_ok_nonempty || stdfail
}

@test "$bin help" "Lists commands" {
  run $BATS_TEST_DESCRIPTION
  # Output must at least be usage lines + nr of functions
  { test $status -eq 0 &&
    test "${#lines[@]}" -gt 8
  } || stdfail
}

@test ". ${bin}" {
  run sh -c "$BATS_TEST_DESCRIPTION"
  { test ${status} -eq 1 &&
    fnmatch "diskdoc: not a frontend for sh*" "${lines[*]}"
  } || stdfail 1

  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 1 &&
    fnmatch "diskdoc: not a frontend for bats-exec-test*" "${lines[*]}"
  } || stdfail 2
}

@test ". ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}

@test "source ${bin}" {
  run bash -c "$BATS_TEST_DESCRIPTION"
  { test ${status} -eq 1 &&
    fnmatch "diskdoc: not a frontend for bash*" "${lines[*]}"
  } || stdfail 2
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 1 &&
    fnmatch "diskdoc: not a frontend for bats-exec-test*" "${lines[*]}"
  } || stdfail 1
}

@test "source ${bin} load-ext" {
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}

@test "${bin} -vv -n help" {
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
    test -n "${lines[*]}" && # non-empty output
    test ${#lines[@]} -gt 4  # lines of output (stdout+stderr)
  } || stdfail
}

