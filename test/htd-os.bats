#!/usr/bin/env bats

base=htd-os
load init

setup()
{
  init
}

@test "htd normalize-relative" {

  #TODO "fix at travis"
  check_skipped_envs travis jenkins || \
    skip "$BATS_TEST_DESCRIPTION not running at Linux (Travis)"

  test -n "$TERM" || export TERM=dumb
 
  run $BATS_TEST_DESCRIPTION 'Foo/Bar/.'
  test_ok_nonempty '*Foo/Bar' || stdfail 1

  export verbosity=3 
  run $BATS_TEST_DESCRIPTION 'Foo/Bar/.'
  test_ok_nonempty 'Foo/Bar' || stdfail 2
  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/./')" = 'Foo/Bar/'

  run $BATS_TEST_DESCRIPTION 'Foo/Bar/../'
  test_ok_nonempty Foo/ || stdfail 3

  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/../')" = 'Foo/'
  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/..')" = 'Foo'

  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/../..')" = '.'
  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/../')" = 'Foo/'
  test "$($BATS_TEST_DESCRIPTION '/Foo/Bar/..')" = '/Foo'
  test "$($BATS_TEST_DESCRIPTION '/Foo/Bar/../')" = '/Foo/'

  test "$($BATS_TEST_DESCRIPTION '/Dev/../Home/Living Room')" = "/Home/Living Room"
  test "$($BATS_TEST_DESCRIPTION '/Soft Dev/../Home/Shop')" = "/Home/Shop"

  test "$($BATS_TEST_DESCRIPTION .)" = "."
  test "$($BATS_TEST_DESCRIPTION ./)" = "./"
}
