#!/usr/bin/env bats

base=mimereg

load helper


@test "$bin ffnenc.py" {
  check_skipped_envs travis || skip "FIXME $BATS_TEST_DESCRIPTION"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${#lines[@]}" = "1"
  test "${lines[0]}" = "ffnenc.py: text/x-python"
}

@test "$bin -q ffnenc.py" {
  check_skipped_envs travis || skip "FIXME $BATS_TEST_DESCRIPTION"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${#lines[@]}" = "1"
  test "${lines[0]}" = "text/x-python"
}

@test "$bin -qE ffnenc.py" {
  check_skipped_envs travis || skip "FIXME $BATS_TEST_DESCRIPTION"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${#lines[@]}" = "1"
  test "${lines[0]}" = "py"
}

