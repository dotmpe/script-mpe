#!/usr/bin/env bats

load helper
base=projectdir.sh

init
. $lib/util.sh


@test "${bin}" "default no-args" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
}


@test "${bin} help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*projectdir.sh <cmd> *" "${lines[*]}"
}


