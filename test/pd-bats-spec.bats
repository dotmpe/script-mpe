#!/usr/bin/env bats

load helper
base="projectdir.sh"

init

setup()
{
  . $lib/util.sh
}

# Static, local tests for projectdir-bats.inc.sh

@test "${base} bats-files" "(2) local script-mpe test files" {

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ${#lines[@]} -gt 20
}


@test "${base} bats-gnames" "(2) local script-mpe test files" {

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ${#lines[@]} -gt 20
}

# vim:ft=bash:
