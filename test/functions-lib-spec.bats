#!/usr/bin/env bats

load init
base=functions.lib

setup()
{
  init &&
  lib_load sys src functions
}

@test "$base: list" {

  run functions_list "functions.lib.sh"
  { test_ok_nonempty 11 && \
    test_lines "functions_list() # *"
  } || stdfail
}
