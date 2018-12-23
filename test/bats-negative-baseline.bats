#!/usr/bin/env bats

load init
base='baseline:bats-negative'

setup()
{
  init 0 0
}


@test "$base: vanilla shell I" {

  run true
  test ${status} -ne 0
}

@test "$base: vanilla shell II" {

  run false
  test ${status} -eq 0
}

@test "$base: vanilla shell III" {

  run false
  test -n "${lines}"
}


@test "$base: assert lib I" {

  load assert

  run true
  assert_failure
}

@test "$base: assert lib II" {

  load assert

  run false
  assert_success
}

@test "$base: assert lib III" {

  load assert

  run true
  assert_output "123"
}

@test "$base: assert lib IV" {

  load assert

  run echo 123
  assert_output ""
}
