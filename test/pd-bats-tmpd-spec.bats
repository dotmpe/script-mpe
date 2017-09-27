#!/usr/bin/env bats

load helper
base="projectdir.sh"

init
. $lib/util.sh


# Tests for projectdir-bats.inc.sh

setup()
{
  tmpd
  cd $tmpd
  diag "tmpd=$tmpd"
  export verbosity=4
}
teardown()
{
  rm -rf $tmpd
}

@test "${base} bats-files" "" {

  mkdir test
  touch test/{foo,bar,baz}-spec.bats

  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
    test ${#lines[@]} -ge 3
  } || stdfail 1
 
  mkdir test/sub
  touch test/sub/{foo2,bar2}-spec.bats

  export pd_trgtglob="test/sub/*-spec.bats test/*-spec.bats"
  run $BATS_TEST_DESCRIPTION 
  {
    test ${status} -eq 0 &&
    test ${#lines[@]} -ge 5
  } || stdfail 2

  rm -rf $tmpd
}

@test "${base} bats-gnames" "" {

  mkdir test
  touch test/{foo,bar,baz}-spec.bats

  run $BATS_TEST_DESCRIPTION 
  {
    test ${status} -eq 0 &&
    test ${#lines[@]} -eq 3 &&
    test bar = "${lines[0]}" &&
    test baz = "${lines[1]}" &&
    test foo = "${lines[2]}"
  } || stdfail 1
 
  mkdir test/sub
  touch test/sub/{foo2,bar2}-spec.bats

  run $BATS_TEST_DESCRIPTION 
  {
    test ${status} -eq 0 &&
    test ${#lines[@]} -eq 3 &&
    test bar = "${lines[0]}" &&
    test baz = "${lines[1]}"
  } || stdfail 2
  
  export pd_trgtglob="test/sub/*-spec.bats test/*-spec.bats"
  run $BATS_TEST_DESCRIPTION 
  {
    test ${#lines[@]} -eq 5 &&
    test "bar2 foo2 bar baz foo" = "${lines[*]}"
  } || stdfail 3
}

# vim:ft=bash:
