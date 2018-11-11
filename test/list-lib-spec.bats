#!/usr/bin/env bats

base=list.lib
load init
init

testf1=test/var/table-1.tab
testf2=test/var/nix_comments.txt

setup()
{ 
  load helper &&
# TODO: group with list(format) or re-distribute over os, src, table..
  lib_load src table
}


@test "$base: grep-head-comment-line: AB-test" {

  run grep_head_comment_line $testf1
  { test_ok_nonempty 1 && test_lines "Description: something."; } || stdfail 1

  run grep_head_comment_line $testf2
  test_nok_empty || stdfail 2
}

@test "$base: read-head-comment $testf1" {

  run read_head_comment "$testf1"
  # NOTE: Empty lines by BATS only
  { test_ok_lines \
        "Description: something." \
        "FOO      BAR            BAZ"
  } || stdfail 1
 
  load assert
  read_head_comment "$testf1"
  assert_equal "$first_line" "2"
  assert_equal "$last_line" "4"
}

@test "$base: grep-list-head: returns fields from first header line" {
  run grep_list_head test/var/table-1.tab
  { test_ok_nonempty 1 && test_lines "FOO      BAR            BAZ"; } || stdfail

  run grep_list_head test/var/urls1.outline
  test_nok_empty || stdfail 2
}
