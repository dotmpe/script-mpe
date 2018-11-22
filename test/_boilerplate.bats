#!/usr/bin/env bats

load init
base=boilerplate
#init
#init_bin
#load assert

setup()
{
  init &&
  load assert &&
  lib_load setup-sh-tpl date &&
  tmpd &&
  diag "$BATS_TEST_NUMBER. Tmp-Dir: $tmpd ($BATS_TEST_DESCRIPTION)"
}

teardown()
{
  cd "$BATS_CWD"
  # remove tmpdir for clean tests
  test -n "$BATS_ERROR_STATUS" || rm -rf "$tmpd"
}


@test "$base -vv -n help" {
  skip "some reason to skip test"
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}

@test "${base}: function should ..." {
  TODO fix this or that # tasks-ignore
  run function args
  { test_ok_nonempty 1 && test_lines "args" "..." 
  } || stdfail
}

#@test "${lib}/${base} - function should ..." {
#  check_skipped_envs || \
#    TODO "envs $envs: implement lib (test) for env" # tasks-ignore
#  diag $BATS_TEST_DESCRIPTION
#  run function args
#  test_lines, test_ok_lines, test_nok_lines
#}
