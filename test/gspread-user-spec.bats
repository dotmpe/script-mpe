#!/usr/bin/env bats

load init
init

setup()
{
  ENV_NAME=gspread-boreas . ~/.bashrc
  lib_load projectenv
}

@test "gspread user API" {
  require_env user
  TODO above env ID user doesnt exist. really want to pass some selectors on invocation

  run python x-gspread.py
  test_ok_nonempty || stdfail
}
