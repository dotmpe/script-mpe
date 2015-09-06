#!/usr/bin/env bats

base=box

load helper

usage_line_1="${base}.sh Bash/Shell script helper"
usage_line_2="Usage:"
usage_line_3="  ${base} <cmd> [<args>..]"


@test "$bin no arguments no-op" {
  check_skipped_envs travis || skip "FIXME $envs: not running on $env"

  run bash -c 'cd /tmp/ && '${bin}
  lines_to_file /tmp/1
  echo $status >> /tmp/1

  test $status -eq 1

  skip "FIXME: $BATS_TEST_DESCRIPTION"

  # TODO: Meh.. test [[ "${lines[0]}" =~ "No.script.for" ]]
  # XXX: Also buggy on OSX 10.8.5: removed idx for now
  case "$uname" in
      Linux ) idx=0 num=3 ;;
      Darwin ) idx=1 num=4 ;;
  esac

#echo ${lines[*]} | grep No.local.script.for || test
  #test "${#lines[@]}" = "$num"
}

@test "${bin} help" {
  check_skipped_envs travis || skip "FIXME $envs: not running on $env"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  #test "${lines[0]}" = "$usage_line_1"
  #test "${lines[1]}" = "$usage_line_2"
  #test "${lines[2]}" = "$usage_line_3"
  test "${#lines[@]}" = "10"
}

@test "${bin} check-install" {
  check_skipped_envs travis || skip "FIXME $envs: not running on $env"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} -i" {
  tmpf=/tmp/bats-test-spec-foo/bar/3/baz_4
  #tmpf
  mkdir -vp $tmpf
  pushd $tmpf
  expect=_tmp_bats_test_spec_foo_bar_3_baz_4
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

