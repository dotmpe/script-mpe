#!/usr/bin/env bats

base=htd
load init
init
pwd=$(cd .;pwd -P)

version=0.0.4-dev # script-mpe

setup()
{
  export SCR_SYS_SH=
  sys_lib_load
  type require_env >/dev/null 2>&1 && {
    . ./tools/sh/init.sh
    lib_load projectenv env-deps
  } || {
    . ./tools/ci/env.sh
    project_env_bin node npm lsof
  }
}

@test "$bin prefixes" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin prefixes names" {
  require_env lsof
  export verbosity=5
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin prefixes name" {
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin prefixes pairs" {
  export verbosity=5
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}
