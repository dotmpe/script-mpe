#!/usr/bin/env bats

base=htd
load helper
init
source $lib/util.sh
source $lib/str.lib.sh


version=0.0.0+20150911-0659 # script.mpe

@test "$bin normalize-relative" {

  check_skipped_envs travis jenkins || \
    skip "$BATS_TEST_DESCRIPTION not running at Linux (Travis)"

  test -n "$TERM" || export TERM=dumb
  run $BATS_TEST_DESCRIPTION 'Foo/Bar/..'
  test ${status} -eq 0
  test "${lines[@]}" = 'Foo'

  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/../..')" = ''
  test "$($BATS_TEST_DESCRIPTION '/Dev/../Home/Living Room')" = "/Home/Living Room"
  test "$($BATS_TEST_DESCRIPTION '/Soft Dev/../Home/Shop')" = "/Home/Shop"

}

