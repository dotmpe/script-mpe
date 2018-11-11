#!/usr/bin/env bats

base=build-checks.lib

load init

setup()
{
  init &&
  lib_load &&
  lib_load build-checks setup-sh-tpl &&
  build_init
}


@test "$base: check_clean test/" {

  run check_clean test/var/
  test_nok_empty || stdfail

  skip FIXME: test only for XXX, in certain dirs. \
    But also rewrite tags to tag-id first.

  run check_clean test/var/build-lib/ test/build*
  test_ok_empty || stdfail
}

#@test "$base: " {
#}
