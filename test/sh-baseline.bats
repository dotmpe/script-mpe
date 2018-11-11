#!/usr/bin/env bats

load init

base=sh-baseline


setup()
{
  init
  . $SHT_PWD/var/sh-src-main-mytest-funcs.sh
}


@test "${base}: true equals success" {

  func_exists true
  run true
  test_ok_empty || stdfail
}

@test "${base}: false equals failure" {

  func_exists false
  run false
  test_nok_empty || stdfail
}


@test "$base: run functions" "" "" {

  run mytest_function
  test $status -eq 0
  test "${lines[0]}" = "mytest"

  run mytest_usage
  test $status -eq 0
  test "${lines[0]}" = "mytest_usage"
}


@test "$base: run non-existing functions" {

  run sh -c 'no_such_function'
  test $status -eq 127

  # XXX: cleanup shell.lib
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


@test "$base: shell-level" {

  run eval echo \$SHLVL
  { test_ok_nonempty && test ${lines[0]} -ge 3
  } || stdfail
}

# Id: script-mpe/0.0.4-dev test/sh-baseline.bats
