#!/usr/bin/env bats

load init
base=package.lib

setup()
{
  init &&
  load assert &&
  lib_load package sys
}


@test "$base: environment: " {

  run 
}
