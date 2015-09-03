#!/usr/bin/env bats

bin=box

load helper

usage_line_1="${bin}.sh Bash/Shell script helper"
usage_line_2="Usage:"
usage_line_3="  ${bin} <cmd> [<args>..]"


@test "no arguments no-op" {
  cd /tmp/
  run ${bin}
  test $status -eq 1
  # FIXME: Meh.. test [[ "${lines[0]}" =~ "No.script.for" ]]
  echo ${lines[0]} | grep No.script.for || test
  test "${#lines[@]}" = "1"
}

@test "${bin} help" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${lines[0]}" = "$usage_line_1"
  test "${lines[1]}" = "$usage_line_2"
  test "${lines[2]}" = "$usage_line_3"
  test "${#lines[@]}" = "9"
}


@test "${bin} -i" {
  target=/tmp/foo/bar/3/baz_4
  mkdir -vp $target
  pushd $target
  expect=_tmp_foo_bar_3_baz_4
#  run $BATS_TEST_DESCRIPTION
  popd
#  test $status -eq 0
#  test "${#lines[@]}" = "8"
#test -e ""
}

# TODO delete
#@test "${bin} -d" {
#  run $BATS_TEST_DESCRIPTION
#  test $status -eq 0
#}

