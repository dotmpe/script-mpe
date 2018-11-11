#!/usr/bin/env bats

base=build

load init

setup()
{
  init &&
  lib_load &&
  #. build.sh &&
  lib_load build
}

@test "$base: build_specs_static" {

  TODO "run build_specs_static"
}
