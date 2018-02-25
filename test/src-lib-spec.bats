#!/usr/bin/env bats

load init
base=argv.lib

init
. $lib/util.sh


@test "$lib/${base} header-comment test/var/nix_comments.txt prints file header comment, exports env" {
  local testf=test/var/nix_comments.txt r=
  header_comment $testf > $testf.header || r=$?
  md5ck="$(echo $(md5sum $testf.header | awk '{print $1}'))"
  rm $testf.header
  test -z "$r" 
  test "$md5ck" = "b37a5e1dd5f33d5ea937de72587052c7"
  test $line_number -eq 4
}


@test "$lib/${base} backup-header-comment test/var/nix_comments.txt writes comment-header file" {
  local testf=test/var/nix_comments.txt
  run backup_header_comment $testf
  test $status -eq 0
  test -z "${lines[*]}"
  test -s $testf.header
  test "$(echo $(md5sum $testf.header | awk '{print $1}'))" \
    = "b37a5e1dd5f33d5ea937de72587052c7"
}


@test "$lib truncate_trailing_lines: " {

  echo
  tmpd
  out=$tmpd/truncate_trailing_lines
  printf "1\n2\n3\n4" >$out
  test -s "$out"
  ll="$(truncate_trailing_lines $out 1)"
  test -n "$ll"
  test "$ll" = "4"
}


@test "$lib file_insert_where_before" {
  TODO
}

@test "$lib file_insert_at" {
  TODO
}

@test "$lib file_where_before" {

  func_exists file_where_before
  run file_where_before
  {
    test $status -eq 1 &&
    fnmatch "*where-grep arg required*" "${lines[*]}"
  } || stdfail

  run file_where_before where
  {
    test $status -eq 1 &&
    fnmatch "*file-path or input arg required*" "${lines[*]}"
  } || stdfail
}

