#!/usr/bin/env bats

load init
base=vc.lib

setup()
{
  testf1="test/var/todo.txt"
  init && load assert && lib_load vc
}


@test "$base: vc-commit-for-line" {

  run vc_commit_for_line "$testf1" 1 5 6
  {
    test_ok_nonempty 3 &&
	test_lines "f72b61be*" "6bab75ca*" "ddefaf5b*"
  } || stdfail

  assert fnmatch "f72b61be*" "$(vc_commit_for_line "$testf1" 1)"
  assert fnmatch "f72b61be*" "$(vc_commit_for_line "$testf1" 2)"
  assert fnmatch "f72b61be*" "$(vc_commit_for_line "$testf1" 3)"
  assert fnmatch "f72b61be*" "$(vc_commit_for_line "$testf1" 4)"
  assert fnmatch "6bab75ca*" "$(vc_commit_for_line "$testf1" 5)"
  assert fnmatch "ddefaf5b*" "$(vc_commit_for_line "$testf1" 6)"
}
