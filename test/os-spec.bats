#!/usr/bin/env bats

base=htd
load helper
init
source $lib/util.sh
source $lib/str.sh


version=0.0.0+20150911-0659 # script.mpe

@test "$bin normalize-relative" {

  check_skipped_envs linux || \
    skip "$BATS_TEST_DESCRIPTION not running at Linux (Travis)"

  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/..')" = 'Foo'
  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/../..')" = ''
  test "$($BATS_TEST_DESCRIPTION '/Dev/../Home/Living Room')" = "/Home/Living Room"
  test "$($BATS_TEST_DESCRIPTION '/Soft Dev/../Home/Shop')" = "/Home/Shop"

}

