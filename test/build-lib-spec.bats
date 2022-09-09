#!/usr/bin/env bats

base=build.lib

load init

setup()
{
  init &&
  lib_load &&
  lib_load build-htd setup-sh-tpl &&
  build_init
}


@test "$base: exec-args-lines" {

  run exec_arg_lines A -- B C -- E
  test_ok_lines "A" "B C" "E" || stdfail 1

  run exec_arg_lines -- A -- -- BC -- -- --
  test_ok_lines "A" "BC" || stdfail 2
}
