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

# FIXME: bail out if config is missing, iso skipping all tests
# Not sure what this means for test plan

@test "${bin} -q radical-test1.txt" {

  test -e "$HOME/.cllct.rc" || skip "cllct not configured"

  check_skipped_envs travis || \
    TODO "envs $envs: implement for env"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  #test -z "${lines[*]}" # empty output
  # lines of output (stderr+stderr)
  test "${#lines[@]}" = "10" \
    || fail "${#lines[@]}"
}

@test "${bin} radical-test1.txt" {
  test -e "$HOME/.cllct.rc" || skip "cllct not configured"
  check_skipped_envs travis || \
    TODO "envs $envs: implement for env"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
  # 6 'note'-level log lines, three for issues: TODO: fix multiline scanning
  test "${#lines[@]}" = "12" || fail "Lines: ${#lines[@]}" # lines of output (stderr+stderr)
}

@test "${bin} radical run-embedded-issue-scan - has to run without faults" {
  run htd -q radical-scan
}

@test "${bin} test/var/radical-tasks-1.txt" {

	TODO

	t=test/var/radical-tasks-1.txt
	run ${bin} --issue-format todo.txt $t

	run ${bin} --issue-format id $t
	test "${lines[2]}" = "test/var/radical-tasks-1.txt:3-66" \
		|| fail "2: ${lines[2]}"

	run ${bin} --issue-format full-id $t
	test "${lines[2]}" = "test/var/radical-tasks-1.txt:3-66;lines=2-2;flavour=unix_generic;comment=3-66" \
		|| fail "2: ${lines[2]}"

	run ${bin} --issue-format full-sh $t
	test "${lines[2]}" = "test/var/radical-tasks-1.txt::::3-66: TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit." \
		|| fail "2: ${lines[2]}"

	run ${bin} --issue-format raw $t
	test "${lines[2]}" = "test/var/radical-tasks-1.txt (2, 2) unix_generic 'TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n' 'TODO: Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n'" \
		|| fail "2: ${lines[2]}"

	run ${bin} --issue-format raw2 $t
}

@test "${bin} test/var/radical-tasks-2.txt" {

	TODO

	t=test/var/radical-tasks-1.txt
	run ${bin} --issue-format todo.txt $t

	run ${bin} --issue-format id $t
	test "${lines[2]}" = "test/var/radical-tasks-1.txt:3-66" \
		|| fail "2: ${lines[2]}"

	run ${bin} --issue-format full-id $t
	test "${lines[2]}" = "test/var/radical-tasks-1.txt:3-66;lines=1-1;flavour=unix_generic;comment=3-66" \
		|| fail "2: ${lines[2]}"
}


