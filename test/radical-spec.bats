#!/usr/bin/env bats

load init
base=./radical.py

init


@test "${bin} --help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
}
@test "${bin} -vv -h" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
}

@test "${bin} - run-embedded-issue-scan - has to run without fault" {
  t=test/var/radical-tasks-1.txt
  run ${bin} -q $t
  test_ok_nonempty || stdfail
  run ${bin} $t
  test_ok_nonempty || stdfail
  run ${bin} --issue-format=todo.txt $t
  test_ok_nonempty || stdfail
}

@test "${bin} radical-test1.txt" {
  # TODO: setup user config and cleanup
  #test -e "$HOME/.cllct.rc" || skip "cllct not configured"
  #check_skipped_envs travis || \
  #  TODO "envs $envs: implement for env"
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
    test -n "${lines[*]}" && # non-empty output
    test "${#lines[@]}" = "9" # lines of output (stderr+stderr)
  } || stdfail
}

@test "${bin} radical-test1.txt" {
  #test -e "$HOME/.cllct.rc" || skip "cllct not configured"
  #check_skipped_envs travis || \
  #  TODO "envs $envs: implement for env"
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
    test -n "${lines[*]}" && # non-empty output
    # 6 'note'-level log lines, three for issues: TODO: fix multiline scanning
    test "${#lines[@]}" = "9" # lines of output (stderr+stderr)
  } || stdfail
}

@test "${bin} - reads paths from stdin with '--input' " {

  t=test/var/radical-tasks-1.txt
  _test()
  {
    echo $t | ${bin} --input - --issue-format todo.txt
  }
  run _test
  test_ok_nonempty || stdfail
}

@test "${bin} - has known output formats: full-id, raw2, todo.txt, raw, id, grep, full-sh" {
  local t=test/var/radical-tasks-1.txt

  run ${bin} --list-formats
  { test_ok_nonempty &&
    test "${lines[*]}" = "full-id raw todo.txt raw2 grep json-stream null id full-sh" 
  } || stdfail list-formats

  for fmt in full-id todo.txt raw raw2 id full-sh
  do
    run ${bin} -q --issue-format $fmt $t
    test_ok_nonempty || stdfail $fmt
  done
}

@test "${bin} - raises exception on unknown format" {
  local t=test/var/radical-tasks-1.txt
  run ${bin} --issue-format invalid-format $t
  { test $status -ne 0 &&
    fnmatch "*Unknown format*" "${lines[*]}"
  } || stdfail 
}

@test "${bin} test/var/radical-tasks-1.txt results" {
  local t=test/var/radical-tasks-1.txt

  run ${bin} -q --issue-format full-sh $t
  { test $status -eq 0 &&
	test "${lines[0]}" = ':test/var/radical-tasks-1.txt:2-2:2-66::::  TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n' &&
    test ${#lines[@]} -eq 1
  } || stdfail 1:full-sh
 
  run ${bin} -q --issue-format grep $t
  { test $status -eq 0 &&
    test "${lines[0]}" = 'test/var/radical-tasks-1.txt:2:  TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n' &&
    test ${#lines[@]} -eq 1
  } || stdfail 2:grep
 
  run ${bin} -q --issue-format id $t
  { test $status -eq 0 &&
    test "${lines[0]}" = "test/var/radical-tasks-1.txt:3-67" &&
    test ${#lines[@]} -eq 1
  } || stdfail 3:id

  run ${bin} -q --issue-format full-id $t
  { test $status -eq 0 &&
    test "${lines[0]}" = "test/var/radical-tasks-1.txt:3-67;lines=2-2;flavour=unix_generic;comment=4-67" &&
    test ${#lines[@]} -eq 1
  } || stdfail 4:full-id

  run ${bin} -q --issue-format todo.txt $t
  { test $status -eq 0 &&
    test ${#lines[@]} -eq 1
  } || stdfail "5:todo.txt" #, line-0: '${lines[0]}', status"
  # FIXME: todo.txt format output test characters have something odd going on
  #test "${lines[0]}" = "TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit."\
  #" +test/var/radical-tasks-1.txt line:2-2 char:3-66 " &&
}


@test "${bin} test/var/radical-tasks-2.txt" {
  local t=test/var/radical-tasks-2.txt

  run ${bin} -q --issue-format full-sh $t
  { test $status -eq 0 &&
    test ${#lines[@]} -eq 1
  } || stdfail 1:full-sh
 
  run ${bin} -q --issue-format id $t
  { test $status -eq 0 &&
    test ${#lines[@]} -eq 1
  } || stdfail 2:id

  run ${bin} -q --issue-format full-id $t
  { test $status -eq 0 &&
    test ${#lines[@]} -eq 1
  } || stdfail 3:full-id

  run ${bin} -q --issue-format todo.txt $t
  { test $status -eq 0 &&
    test ${#lines[@]} -eq 1
  } || stdfail 4:todo.txt
}


@test "${bin} test/var/radical-tasks-4.txt" {
  local t=test/var/radical-tasks-4.txt

  run ${bin} -q --issue-format full-sh $t
  { test $status -eq 0 &&
    test ${#lines[@]} -eq 4
  } || stdfail 1:full-sh
 
  run ${bin} -q --issue-format id $t
  { test $status -eq 0 &&
    test ${#lines[@]} -eq 4
  } || stdfail 2:id

  run ${bin} -q --issue-format full-id $t
  { test $status -eq 0 &&
    test ${#lines[@]} -eq 4
  } || stdfail 3:full-id

  run ${bin} -q --issue-format todo.txt $t
  { test $status -eq 0 &&
    test ${#lines[@]} -eq 4
  } || stdfail 4:todo.txt
}


