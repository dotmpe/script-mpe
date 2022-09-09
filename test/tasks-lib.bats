#!/usr/bin/env bats

load init
base=tasks.lib

setup()
{
  init && load assert && lib_load list todo vc-htd tasks
}


@test "$base: add-dates-from-scm-or-default" {

  tasks_echo=1 run tasks_add_dates_from_scm_or_def test/var/todo.txt
  {
    test_ok_nonempty 6 && test_lines \
		"* 2017-03-19 *" \
		"* 2017-03-20 *"
  } || stdfail

  assert fnmatch "(D) 2017-03-20 clean up *" "${lines[2]}"
  assert fnmatch "(F) 2017-03-20 foo *" "${lines[3]}"
  assert fnmatch "2018-12-02 Edit edit *" "${lines[4]}"
  assert fnmatch "x 2018-12-02 Minor edit to *" "${lines[5]}"
}
