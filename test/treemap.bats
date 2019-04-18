#!/usr/bin/env bats

load init

setup()
{
  init && load stdtest
}

@test "treemap.py help" {

  for opt in "--help" "-h" "-?"
  do
    run ./treemap.py $opt
    test_ok_nonempty || stdfail "$opt"
  done
}

@test "./treemap.py doc" {

  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}
