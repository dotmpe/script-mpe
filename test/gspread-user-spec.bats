#!/usr/bin/env bats

base=gspread
load init
init

setup()
{
  ENV_NAME=gspread-boreas . ~/.local/etc/private-env.sh && lib_load projectenv
# XXX: test -n "$Project_Env_Requirements" || Project_Env_Requirements=user
}

@test "gspread user API" {
#  require_env user
#  TODO above env ID user doesnt exist. really want to pass some selectors on invocation

  run python x-gspread.py
  { test_ok_nonempty 4 &&
      test_lines "<Cell * u'1/14/2014'>" "<Cell * u'3/18/2014'>"
  } || stdfail
}

#@test "txt.py gspread IO" {
#
#  run list.py read-log
#  test_ok_nonempty || stdfail
#}
