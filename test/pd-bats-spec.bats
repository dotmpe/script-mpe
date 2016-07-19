#!/usr/bin/env bats

load helper
base="projectdir.sh"

init
. $lib/util.sh


@test "${base} bats-files" "" {

  tmpd
  cd $tmpd
  mkdir test
  touch test/{foo,bar,baz}-spec.bats

  run $BATS_TEST_DESCRIPTION
  diag "Output: ${lines[*]}"
  test ${status} -eq 0
  diag "Lines: ${#lines[@]}"
  test ${#lines[@]} -eq 3
 
  mkdir test/sub
  touch test/sub/{foo2,bar2}-spec.bats

  export pd_trgtglob="test/sub/*-spec.bats test/*-spec.bats"
  run $BATS_TEST_DESCRIPTION

  test ${status} -eq 0
  test ${#lines[@]} -eq 5

  rm -rf $tmpd
}


@test "${base} bats-files" "(2) local script-mpe test files" {

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ${#lines[@]} -gt 20
}


@test "${base} bats-gnames" "" {

  tmpd
  #diag "tmpd=$tmpd"
  cd $tmpd
  mkdir test
  touch test/{foo,bar,baz}-spec.bats

  export verbosity=0

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ${#lines[@]} -eq 3
  test bar = "${lines[0]}"
  test baz = "${lines[1]}"
  test foo = "${lines[2]}"
 
  mkdir test/sub
  touch test/sub/{foo2,bar2}-spec.bats

  export pd_trgtglob="test/sub/*-spec.bats test/*-spec.bats"
  run $BATS_TEST_DESCRIPTION

  test ${status} -eq 0
  test ${#lines[@]} -eq 5
  test bar2 = "${lines[0]}"
  test foo2 = "${lines[1]}"
  
  
  run $BATS_TEST_DESCRIPTION bar*
  test ${#lines[@]} -eq 2
  test bar2 = "${lines[0]}"
  test bar = "${lines[1]}"


  rm -rf $tmpd
}


@test "${base} bats-gnames" "(2) local script-mpe test files" {

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ${#lines[@]} -gt 20
}


