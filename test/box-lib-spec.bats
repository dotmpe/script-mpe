#!/usr/bin/env bats

load helper
base=box.lib

init
source $lib/$base.sh
test_lib=$lib/test/main.inc


@test "${lib}/${base} - box-script-insert-point should return the line before std script functions" {

  check_skipped_envs travis || skip "FIXME broken after main.lib.sh rewrite"
  run box_script_insert_point $test_lib.bash "" load mytest

  test ${status} -eq 0
  test "${lines[*]}" = "22"
  test "${#lines[@]}" = "1" # lines of output (stderr+stderr)

  run box_script_insert_point $test_lib.bash run "" c_mytest

  #echo ${status} > /tmp/1
  #echo "${lines[*]}" >> /tmp/1
  test ${status} -eq 0
  test "${lines[*]}" = "11"
  test "${#lines[@]}" = "1" # lines of output (stderr+stderr)

  # FIXME test does not include setting prefix, this'll work though
#  script_name=c_mytest
#  run box_script_insert_point $test_lib.bash 
#
#  test ${status} -eq 0
#  test "${lines[*]}" = "16"
#  test "${#lines[@]}" = "1" # lines of output (stderr+stderr)
}


@test "${lib}/${base} - box-grep should detect sentinel lines, and set env or return 1. No output. " {

  base=mytest
  subcmd=load
  where_line=
  where_grep='.*#.--.'${base}'.box.*'${subcmd}'.sentinel.--'
  box_grep $where_grep $test_lib.bash
  r=$?
  echo "${where_line}" >/tmp/1
  test "${where_line}" = "25:  # -- mytest box $subcmd sentinel --"
  test $r -eq 0

  # again without where_line export
  run box_grep $where_grep $test_lib.bash
  test -z "${lines[*]}" # empty output
  test "${#lines[@]}" = "0" # lines of output (stderr+stderr)
  test ${status} -eq 0

  script_name=mytest
  subcmd=no-such-id
  where_grep='.*#.--.'${script_name}'.box.'${subcmd}'.sentinel.--'
  run box_grep $where_grep $test_lib.bash
  test ${status} -eq 1
  test -z "${lines[*]}" # empty output
  test "${#lines[@]}" = "0" # lines of output (stderr+stderr)
}


@test "${lib}/${base} box-list-libs" {
  run box_list_libs box.sh box
  { test ${status} -eq 0 &&
    test "${lines[*]}" = "  debug \"Using \$LOG_TERM log output\""
  } || stdfail
}


@test "${lib}/${base} box-src-lib" {
  skip FIXME
  run box_src_lib box.sh box
  diag "${lines[*]}"
  { test ${status} -eq 0 &&
    test -z "${lines[*]}" # empty output
  } || stdfail
}


