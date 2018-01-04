#!/usr/bin/env bats

base=htd
load helper
init
pwd=$(cd .;pwd -P)

version=0.0.4-dev # script-mpe

setup()
{
  . ./tools/sh/init.sh
  lib_load projectenv env-deps
}

@test "$bin prefixes" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin prefix-names" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin prefixes name" {
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin prefixes pairs" {
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}
