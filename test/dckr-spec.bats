#!/usr/bin/env bats

load helper
base=dckr

init_bin
init_lib
. $lib/util.sh


@test "${bin}" {
  check_skipped_envs travis || skip "not running at Travis CI"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
  fnmatch "*No command*" "${lines[*]}" # no-cmd err info on out
  fnmatch "*Error:*" "${lines[*]}"
}

@test "${bin} -h" {
  check_skipped_envs travis || skip "not running at Travis CI"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}

@test "${bin} help" {
  check_skipped_envs travis || skip "not running at Travis CI"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop

#  echo ${status} > /tmp/1
#  echo "${lines[*]}" >> /tmp/1
#  echo "${#lines[@]}" >> /tmp/1
}

@test "${bin} -vv -n help" {
  check_skipped_envs || \
    skip "TODO envs $envs: implement bin (test) for env"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
  test "${#lines[@]}" = "0" # lines of output (stderr+stderr)
}

# vim:et:ft=sh:
