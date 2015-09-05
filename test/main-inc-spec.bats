#!/usr/bin/env bats

test -z "$PREFIX" && lib=./util || lib=$PREFIX/bin/util
source $lib.sh

load helper


mytest_load()
{
  echo mytest_load
}

test_mytest_load()
{
  echo \$0=$0
  echo \$*=$*
  echo \$lib=$lib
  source $lib.sh
  try_load mytest
}

@test "$lib test run test function to verify" {
  run mytest_function
  test $status -eq 0
  test ${lines[0]} = "mytest"
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
  # FIXME test "${lines[0]}" = "./util.sh: line *: type: no_such_function: not found"
  test $status -eq 1
}

@test "$lib try_load " {

  skip TODO fix
  source $lib'.sh'
  run try_load mytest
  echo $status > /tmp/test-x
  echo "${lines[0]}" >> /tmp/test-x
  test $status -eq 0
  #lines_to_file
}

@test "$lib sh try_load " {
  skip TODO fix
  run sh -c '. '$lib'.sh && try_load mytest'
  test $status -eq 0
  #lines_to_file
}

@test "$lib native bats try_load " {
  skip TODO fix
  run test_mytest_load
  #lines_to_file
}



