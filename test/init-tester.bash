#!/bin/sh

init_tester__run_load()
{
  util_mode=ext . $scriptpath/util.sh &&
  lib_load "$@"
}

init_tester__run_boot()
{
  scriptpath=$HOME/bin __load=boot . ./util.sh;
}

init_tester__baseline__test_env()
{
  test -z "$1" ||
    assert_equal "$1" "$BATS_TEST_NUMBER"
  test -z "$2" ||
    assert_equal "$2" "$PWD" # PWD is unchanged
  assert_equal "$PWD" "$(pwd)" # PWD is unchanged
  assert_equal "$PWD" "$BATS_CWD" # PWD envs match
  assert_equal "$PWD/test" "$BATS_TEST_DIRNAME"
}

init_tester__assert()
{
  test_ok_empty || stdfail "$1"
  shift
  init_tester__baseline__test_env "$@"
}

init_tester__test_lib_load()
{
  init_tester__run_load $1

  lvid=$(printf -- "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g')
  assert_equal "$(eval echo \$${lvid}_lib_loaded)" "0"

  init_tester__assert "$@"
}

init_tester__baseline__run()
{
  local pwd=$(pwd) testnr="$1" ; shift
  while test $# -gt 0
  do
    run init_tester__test_lib_load "$1" $testnr $pwd
    shift
  done
}
