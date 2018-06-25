#!/usr/bin/env bats

load init
init

setup()
{
  ENV_NAME=gspread-boreas . ~/.bashrc
  lib_load projectenv
#  test -n "$Project_Env_Requirements" || Project_Env_Requirements=user
}

@test "gspread user API" {
#  require_env user
#  TODO above env ID user doesnt exist. really want to pass some selectors on invocation

  run python x-gspread.py
  { fnmatch "* '1/14/2014'*" "${lines[*]}" &&
    fnmatch "* '3/18/2014'*" "${lines[*]}" &&
    test_ok_nonempty
  } || stdfail
}

#@test "txt.py gspread IO" {
#
#  run list.py read-log
#  test_ok_nonempty || stdfail
#}
