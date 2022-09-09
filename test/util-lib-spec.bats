#!/usr/bin/env bats

base=util.lib
load init


# Test init.bash, helper.bash

@test "$base: baseline: test env" {

  load assert
  load init-tester

  init_tester__baseline__test_env 1
}

@test "$base: baseline: script env load-ext" {

  skip "FIXME"
  load assert
  load init-tester

  init_tester__baseline__run 2 \
    sys os std stdio str main date match package functions
}

@test "$base: baseline: script env util boot" {

  load assert
  load init-tester

  local pwd=$(pwd) testnr=3

  inner() {
    init_tester__baseline__test_env $testnr $pwd
    init_tester__run_boot
    init_tester__baseline__test_env $testnr $pwd
  }

  init_tester__baseline__test_env $testnr $pwd
  run inner

  test_ok_empty || stdfail ""
  init_tester__baseline__test_env $testnr $pwd

  run /bin/sh '. '"$SHT_PWD"'/init-tester.bash && init_tester__run_boot'
  init_tester__baseline__test_env $testnr $pwd
}
