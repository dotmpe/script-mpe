#!/usr/bin/env bats

base=box

load helper

uname=$(uname)

usage_line_1="${base}.sh Bash/Shell script helper"
usage_line_2="Usage:"
usage_line_3="  ${base} <cmd> [<args>..]"


@test "$bin no arguments no-op" {
  test -z "$TRAVIS_SKIP" || skip "FIXME not running on travis"
  cd /tmp/
  run ${bin}
  test $status -eq 1
  # TODO: Meh.. test [[ "${lines[0]}" =~ "No.script.for" ]]
  # XXX: Also buggy on OSX 10.8.5:
  case "$uname" in
      Linux ) idx=0 num=1 ;;
      Darwin ) idx=1 num=2 ;;
  esac
  echo ${lines[$idx]} | grep No.script.for || test
  test "${#lines[@]}" = "$num"
}

@test "${bin} help" {
  test -z "$TRAVIS_SKIP" || skip "FIXME not running on travis"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${lines[0]}" = "$usage_line_1"
  test "${lines[1]}" = "$usage_line_2"
  test "${lines[2]}" = "$usage_line_3"
  test "${#lines[@]}" = "9"
}

@test "${bin} check-install" {
  test -z "$TRAVIS_SKIP" || skip "FIXME not running on travis"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
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

