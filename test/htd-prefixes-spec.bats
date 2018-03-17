#!/usr/bin/env bats

base=htd
load init
init
pwd=$(cd .;pwd -P)

version=0.0.4-dev # script-mpe

setup()
{
  export SCR_SYS_SH=
  export verbosity=0
  #sys_lib_load
  type require_env >/dev/null 2>&1 || {
    lib_load projectenv env-deps
    project_env_bin node npm lsof
  }
}

@test "$bin prefixes" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin prefixes list" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_lines "ROOT" || stdfail
}

@test "$bin prefixes table" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_lines "*:/ ROOT" || stdfail
}

@test "$bin prefixes names" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION $HOME/bin $HOME/.conf
  test_ok_nonempty || stdfail
}

@test "$bin prefixes name" {
  run $BATS_TEST_DESCRIPTION $HOME/bin
  test_ok_nonempty || stdfail
}

@test "$bin prefixes pairs" {
  run $BATS_TEST_DESCRIPTION $(pwd)
  test_ok_lines "*/bin/ HOME:bin/" || stdfail
}
