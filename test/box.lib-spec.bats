#!/usr/bin/env bats

load helper
base=box.lib

init_lib
source $lib/util.sh
source $lib/$base.sh
test_lib=$lib/test/main.inc


@test "${lib}/${base} - box-script-insert-point should return the line before std script functions" {

  check_skipped_envs vs1 travis || skip "FIXME broken after main.sh rewrite"
  script_name=mytest
  run box_script_insert_point $test_lib.bash

  test ${status} -eq 0
  test "${lines[*]}" = "22"
  test "${#lines[@]}" = "1" # lines of output (stderr+stderr)

  run box_script_insert_point $test_lib.bash load

  test ${status} -eq 0
  test "${lines[*]}" = "27"
  test "${#lines[@]}" = "1" # lines of output (stderr+stderr)

  # XXX test does not include setting prefix, this'll work though
  script_name=c_mytest
  run box_script_insert_point $test_lib.bash run

  test ${status} -eq 0
  test "${lines[*]}" = "16"
  test "${#lines[@]}" = "1" # lines of output (stderr+stderr)
}


@test "${lib}/${base} - box-grep should detect sentinel lines, and set env or return 1. No output. " {

  script_name=mytest
  subcmd_name=main
  where_line=
  where_grep='.*#.--.'${script_name}'.box.*'${subcmd_name}'.sentinel.--'
  box_grep $where_grep $test_lib.bash
  r=$?
  test "${where_line}" = "30:  # -- mytest box include main sentinel --"
  test $r -eq 0

  # again without where_line export
  run box_grep $where_grep $test_lib.bash
  test -z "${lines[*]}" # empty output
  test "${#lines[@]}" = "0" # lines of output (stderr+stderr)
  test ${status} -eq 0

  script_name=mytest
  subcmd_name=no-such-id
  where_grep='.*#.--.'${script_name}'.box.'${subcmd_name}'.sentinel.--'
  run box_grep $where_grep $test_lib.bash
  test ${status} -eq 1
  test -z "${lines[*]}" # empty output
  test "${#lines[@]}" = "0" # lines of output (stderr+stderr)
}


@test "${lib}/${base} - function should ..." {

  check_skipped_envs || \
    skip "TODO envs $envs: implement lib (test) for env"
  #echo ${status} > /tmp/1
  #echo "${lines[*]}" >> /tmp/1
  test -n "${status}" || test -z "run it first!"
  test ${status} -eq 0
  test -z "${lines[*]}" # empty output
  test "${#lines[@]}" = "0" # lines of output (stderr+stderr)
}

# vim:et:ft=sh:
