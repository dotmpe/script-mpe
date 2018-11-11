#!/usr/bin/env bats

load init
base=shell.lib

setup()
{
  init &&
  lib_load shell
}

@test "$base: env" {

  func_exists shell_init
  test -n "$SH_NAME"
  test -n "$IS_BASH_SH"
  test -n "$IS_DASH_SH"
  test -n "$IS_BB_SH"
  test -n "$IS_HEIR_SH"
}
