#!/usr/bin/env bats

load helper
base=vc.sh
init
. $lib/util.sh

@test "$bin no arguments no-op" {
  run $bin
  test $status -eq 0
}

@test "$bin usage" "prints usage" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin help" "prints help" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin version" "prints version" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin list-prefixes" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin uf" "prints unversioned files" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin ufx" "prints unversioned and excluded files" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

