#!/usr/bin/env bats

load init
base='baseline:bats'

setup()
{
  init 0 || err_ "error" "$?" "env-init" "$BATS_TEST_NAME" 1
}


@test "$base: vanilla shell" {

  run true
  test ${status} -eq 0
  test -z "${lines}"

  run false
  test ${status} -ne 0
  test -z "${lines}"
}

@test "$base: assert lib" {

  load assert

  run true
  assert_success
  assert_output ""

  run false
  assert_failure
  assert_output ""
}

@test "$base: helper lib (I)" {

  load extra
  load stdtest

  run true
  test_ok_empty
}

@test "$base: helper lib (II)" {

  load extra
  load stdtest

  run false
  test_nok_empty || stdfail

  run echo 123
  { test_ok_nonempty 1 && test_lines "123"
  } || stdfail
}
