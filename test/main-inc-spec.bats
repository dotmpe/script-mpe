#!/usr/bin/env bats

test -z "$PREFIX" && lib=./util || lib=$PREFIX/bin/util
source $lib.sh

load helper


mytest_function()
{
  echo 'mytest'
}

mytest_load()
{
  mytest_function
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

@test "$lib try_exec_func (bash) on existing function" {
  skip TODO fix
  source $lib.sh
  run try_exec_func mytest_function
  test $status -eq 0
  run bash -c 'source '$lib'.sh && try_exec_func mytest_function'
  test ${lines[0]} = "mytest"
  test $status -eq 0
}

@test "$lib try_exec_func (bash) on non-existing function" {
  skip TODO fix
  run bash -c 'source '$lib'.sh && try_exec_func no_such_function'
  test $status -eq 1
}

@test "$lib bash try_load " {
  skip TODO fix
  run bash -c 'source '$lib'.sh && try_load mytest'
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
  run test_mytest_load
  #lines_to_file
}



