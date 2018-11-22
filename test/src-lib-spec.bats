#!/usr/bin/env bats

load init
base=src.lib
init

testf="test/var/nix_comments.txt"
testf_expected_header_md5="082a6d7b5ff8c0c85a6acf1daa151586"

setup()
{
  lib_load src
}


@test "$base: read-header-comment $testf prints file header comment, exports env" {

  run read_head_comment $testf

  { test_ok_nonempty && test_lines \
      "Header comment lines 1/4" \
      "Header comment lines 2/4" \
      "Header comment lines 3/4" \
      "Header comment lines 4/4"
  } || stdfail

  # Test vars locally
  read_head_comment $testf
  load assert
  assert_equal "$first_line" 1
  assert_equal "$last_line" 4
}


@test "$base: backup-header-comment $testf writes comment-header file" {

  run backup_header_comment $testf
  { test_ok_empty &&
    test -s $testf.header &&
    test "$(echo $(md5sum $testf.header | awk '{print $1}'))" \
      = "$testf_expected_header_md5" &&
    rm $testf.header
  } || stdfail "$testf_expected_header_md5"
}


@test "$base: truncate_trailing_lines: " {

  echo
  tmpd
  out=$tmpd/truncate_trailing_lines
  printf "1\n2\n3\n4" >$out
  test -s "$out"
  ll="$(truncate_trailing_lines $out 1)"
  test -n "$ll"
  test "$ll" = "4"
}


@test "$base: file_insert_where_before" {
  TODO
}

@test "$base: file_insert_at" {
  TODO
}


@test "$base: file_where_before" {

  func_exists file_where_before
  run file_where_before
  {
    test $status -eq 1 &&
    fnmatch "*where-grep arg required*" "${lines[*]}"
  } || stdfail 1.
 
  run file_where_before where
  {
    test $status -eq 1 &&
    fnmatch "*file-where-grep: file-path or input arg required*" "${lines[*]}"
  } || stdfail 2.
}
