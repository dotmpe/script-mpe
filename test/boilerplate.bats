#!/usr/bin/env bats

load helper
base=boilerplate

init_lib
init_bin


@test "${bin} -vv -n help" {
  skip "envs: envs=$envs FIXME is hardcoded in test/helper.bash current_test_env"
  check_skipped_envs $(hostname) || \
    skip "TODO $envs: implement for env $env: $BATS_TEST_DESCRIPTION"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
  test "${#lines[@]}" = "0" # lines of output (stderr+stderr)
}

@test "${lib}/main function should ..." {
  check_skipped_envs $(hostname) || \
    skip "TODO $envs: implement for env $env: $BATS_TEST_DESCRIPTION"
}

# vim:et:ft=sh:
