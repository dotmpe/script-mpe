#!/usr/bin/env bats

test -z "$PREFIX" && lib=./util || lib=$PREFIX/bin/util
source $lib.sh

load helper
load main.inc


@test "$lib test run test functions to verify" {

  run mytest_function
  test $status -eq 0
  test "${lines[0]}" = "mytest"

  run mytest_load
  test $status -eq 0
  test "${lines[0]}" = "mytest_load"
}

@test "$lib test run non-existing function to verify" {

  run sh -c 'no_such_function'
  test $status -eq 127
  test "${lines[0]}" = "sh: 1: no_such_function: not found"

  run bash -c 'no_such_function'
  test $status -eq 127
  test "${lines[0]}" = "bash: no_such_function: command not found"
}

@test "$lib try_exec_func on existing function" {

  source $lib.sh
  run try_exec_func mytest_function
  test "${lines[0]}" = "mytest"
  test $status -eq 0
}

@test "$lib try_exec_func on non-existing function" {

  source $lib'.sh'
  run try_exec_func no_such_function
  test $status -eq 1
}

@test "$lib try_exec_func (bash) on existing function" {

  run bash -c 'source '$lib'.sh \
    && source test/helper.bash \
    && try_exec_func mytest_function'
  test "${lines[0]}" = "mytest"
  test $status -eq 0
}

@test "$lib try_exec_func (bash) on non-existing function" {

  run bash -c 'source '$lib'.sh && try_exec_func no_such_function'
  test "" = "${lines[*]}"
  test $status -eq 1

  run bash -c 'type no_such_function'
  test "bash: line 0: type: no_such_function: not found" = "${lines[0]}"
  test $status -eq 1
}

@test "$lib try_exec_func (sh) on existing function" {

  run sh -c '. '$lib'.sh \
    && . ./test/helper.bash \
    && try_exec_func mytest_function'
  test "${lines[0]}" = "mytest"
  test $status -eq 0
}

@test "$lib try_exec_func (sh) on non-existing function" {

  run sh -c '. '$lib'.sh && try_exec_func no_such_function'
  test "" = "${lines[*]}"
  test $status -eq 127

  run sh -c 'type no_such_function'
  test "no_such_function: not found" = "${lines[0]}"
  test $status -eq 127
}


@test "$lib try_usage (bash)" {

  tmpf bare
  source $lib'.sh'
  try_usage mytest > $tmpf; local r=$?
  test "$(cat $tmpf)" = "mytest_usage"
  test $r -eq 0

  run bash -c 'source '$lib'.sh && source ./test/main.inc.bash && try_usage mytest'
  test $status -eq 0
  test "${lines[0]}" = "mytest_usage"
}

@test "$lib try_usage (sh)" {

  run sh -c '. '$lib'.sh && . ./test/main.inc.bash && try_usage mytest'
  test $status -eq 0
  test "${lines[0]}" = "mytest_usage"
}


@test "$lib try_load" {

  skip "TODO: how not to get caught up with Bats 'load' function"

  run sh -c '. '$lib'.sh && . ./test/main.inc.sh && try_load mytest'
  test $status -eq 0
  test ${lines[0]} = "mytest_load"

  run bash -c 'source '$lib'.sh && source ./test/main.inc.bash && try_load mytest'
  test $status -eq 0
  test ${lines[0]} = "mytest_load"
}


@test "$lib fnmatch" {
  fnmatch "f*o" "foo" || test
  fnmatch "test" "test" || test
  fnmatch "*test*" "test" || test
  fnmatch "*test" "123test" || test
  fnmatch "test*" "test123" || test
}

@test "$lib fnmatch (spaces)" {
  fnmatch "* test" "123 test" || test
  fnmatch "test *" "test 123" || test
  fnmatch "*test*" " test " || test
  fnmatch "./file.sh: line *: test" "./file.sh: line 1234: test" || test
}

