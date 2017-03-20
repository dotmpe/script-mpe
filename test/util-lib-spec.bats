#!/usr/bin/env bats

load helper
base=util-lib
load main.inc

init



@test "$lib/sh (${base}) test run test functions to verify" "" "" {

  run mytest_function
  test $status -eq 0
  test "${lines[0]}" = "mytest"

  run mytest_usage
  test $status -eq 0
  test "${lines[0]}" = "mytest_usage"
}


@test "$lib/sh (${base}) test run non-existing function to verify" {

  run sh -c 'no_such_function'
  test $status -eq 127

  case "$(uname)" in
    Darwin )
      test "sh: no_such_function: command not found" = "${lines[0]}"
      ;;
    Linux )
      test "${lines[0]}" = "sh: 1: no_such_function: not found"
      ;;
  esac

  run bash -c 'no_such_function'
  test $status -eq 127
  test "${lines[0]}" = "bash: no_such_function: command not found"
}

# Id: script-mpe/0.0.4-dev test/util-lib-spec.bats
