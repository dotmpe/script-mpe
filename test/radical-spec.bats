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
  test "${#lines[@]}" = "10" # lines of output (stderr+stderr)
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

