#!/usr/bin/env bats

load helper
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
}

@test "${bin} -q radical-test1.txt" {
	# TODO: cleanup
  #test -e "$HOME/.cllct.rc" || skip "cllct not configured"
  #check_skipped_envs travis || \
  #  TODO "envs $envs: implement for env"
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 &&
		test -n "${lines[*]}" && # non-empty output
		test "${#lines[@]}" = "10" # lines of output (stderr+stderr)
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
    test "${#lines[@]}" = "12" # lines of output (stderr+stderr)
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

@test "${bin} - has known output formats: full-id, raw2, todo.txt, raw, id, full-sh" {
	local t=test/var/radical-tasks-1.txt
  for fmt in full-id raw2 todo.txt raw id full-sh
  do
    case $fmt in raw2|todo.txt )
        diag "FIXME: '$fmt'"; continue
      ;;
    esac
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
  test "${lines[0]}" = ":test/var/radical-tasks-1.txt:3-3:4-67::::TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit." || stdfail 1
 
	run ${bin} -q --issue-format id $t
  test "${lines[0]}" = "test/var/radical-tasks-1.txt:4-67" || stdfail 2

	run ${bin} -q --issue-format full-id $t
	test "${lines[0]}" = "test/var/radical-tasks-1.txt:4-67;lines=2-2;flavour=unix_generic;comment=4-67" || stdfail 3
}

@test "${bin} test/var/radical-tasks-2.txt" {

  TODO
}


