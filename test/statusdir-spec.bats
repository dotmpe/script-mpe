#!/usr/bin/env bats

load helper
base=statusdir.sh

init
. $lib/util.sh



@test "${bin}" "default no-args" {
  #case $(current_test_env) in travis )
  #    skip "TODO $BATS_TEST_DESCRIPTION at travis";;
  #esac
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
}


@test "${bin} help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*statusdir <cmd> *" "${lines[*]}"
}

@test "${bin} root" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test "$HOME/.statusdir/" = "${lines[*]}"
}
