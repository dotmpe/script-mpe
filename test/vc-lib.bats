#!/usr/bin/env bats

load init
base=vc-htd.lib

setup()
{
  testf1="test/var/todo.txt"
  init && load assert && lib_load vc-htd
}


@test "$base: vc-commit-for-line (GIT)" {

  run vc_commit_for_line "$testf1" 1 5 6
  {
    test_ok_nonempty 3 &&
	test_lines "f72b61be*" "6bab75ca*" "be34913bb*"
  } || stdfail "$testf1"

  assert fnmatch "f72b61be*" "$(vc_commit_for_line "$testf1" 1)"
  assert fnmatch "f72b61be*" "$(vc_commit_for_line "$testf1" 2)"
  assert fnmatch "f72b61be*" "$(vc_commit_for_line "$testf1" 3)"
  assert fnmatch "f72b61be*" "$(vc_commit_for_line "$testf1" 4)"
  assert fnmatch "6bab75ca*" "$(vc_commit_for_line "$testf1" 5)"
  assert fnmatch "be34913bb*" "$(vc_commit_for_line "$testf1" 6)"
}


@test "$base: vc-tracked (GIT)" {
  true
}


@test "$base: vc-untracked (GIT)" {
  true
}


@test "$base: vc-modified (GIT)" {
  true
}


@test "$base: vc-git-submodules" {

  load vc-setup
  vc_setup_clean_git
  vc_setup_submodule

  run vc_git_submodules
  test_ok_nonempty || stdfail
}

teardown()
{
  test "$PWD" = "$BATS_CWD" || {
    cd "$BATS_CWD"
  }
  test -z "$tmpd" -o ! -d "$tmpd" || rm -rf "$tmpd"
}
