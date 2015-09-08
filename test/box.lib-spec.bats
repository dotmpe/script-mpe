#!/usr/bin/env bats

load helper
base=box.lib

init_lib
source $lib/util.sh
source $lib/$base.sh
test_lib=$lib/test/main.inc


@test "${lib}/${base} - box-script-insert-point should ..." {

  script_name=mytest
  run box_script_insert_point $test_lib.bash

  test ${status} -eq 0
  test "${lines[*]}" = "22"
  test "${#lines[@]}" = "1" # lines of output (stderr+stderr)
}


@test "${lib}/${base} - function should ..." {

  check_skipped_envs || \
    skip "TODO envs $envs: implement lib (test) for env"
  #echo ${status} > /tmp/1
  #echo "${lines[*]}" >> /tmp/1
  test -z "${lines[*]}" # empty output
  test "${#lines[@]}" = "0" # lines of output (stderr+stderr)
}

# vim:et:ft=sh:
