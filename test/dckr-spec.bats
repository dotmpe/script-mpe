#!/usr/bin/env bats

load helper
base=dckr

init
. $lib/util.sh


@test "${bin}" {
  test -n "$DCKR_VOL" || skip "DCKR_VOL not set"
  # XXX: check_skipped_envs travis simza || skip "dckr not running at Travis CI"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
#  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
  fnmatch "*No command*" "${lines[*]}" # no-cmd err info on out
  fnmatch "*Error:*" "${lines[*]}"
}

@test "${bin} -h" {
  test -n "$DCKR_VOL" || skip "DCKR_VOL not set"
  # XXX: check_skipped_envs travis simza || skip "dckr not running at Travis CI"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
#  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}

@test "${bin} help" {
  test -n "$DCKR_VOL" || skip "DCKR_VOL not set"
  # XXX: check_skipped_envs travis simza || skip "dckr not running at Travis CI"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
#  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop

#  echo ${status} > /tmp/1
#  echo "${lines[*]}" >> /tmp/1
#  echo "${#lines[@]}" >> /tmp/1
}

@test "${bin} -h help" {
  test -n "$DCKR_VOL" || skip "DCKR_VOL not set"
  check_skipped_envs travis simza || skip "dckr not running at Travis CI"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Help 'help':*" "${lines[*]}" # manual on out
  fnmatch "*Usage: * dckr -h|help \[ID]*" "${lines[*]}" # usage info on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}

@test "${bin} help help" {
  test -n "$DCKR_VOL" || skip "DCKR_VOL not set"
  #check_skipped_envs travis simza || skip "dckr not running at Travis CI"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Help 'help':*" "${lines[*]}" # manual on out
  fnmatch "*Usage: * dckr -h|help \[ID]*" "${lines[*]}" # usage info on out
  echo "${lines[*]}" |grep 'Error:' && test -z "errors in output" || noop
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}

