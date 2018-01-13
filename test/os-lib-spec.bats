#!/usr/bin/env bats

base=os.lib
load helper
init


@test "htd normalize-relative" {

  check_skipped_envs travis jenkins || \
    skip "$BATS_TEST_DESCRIPTION not running at Linux (Travis)"

  test -n "$TERM" || export TERM=dumb
  
  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/.')" = 'Foo/Bar'
  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/./')" = 'Foo/Bar/'

  run $BATS_TEST_DESCRIPTION 'Foo/Bar/../'
  test ${status} -eq 0
  test "${lines[*]}" = 'Foo/' || fail "Out: ${lines[*]}"

  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/../')" = 'Foo/'
  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/..')" = 'Foo'

  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/../..')" = '.'
  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/../')" = 'Foo/'
  test "$($BATS_TEST_DESCRIPTION '/Foo/Bar/..')" = '/Foo'
  test "$($BATS_TEST_DESCRIPTION '/Foo/Bar/../')" = '/Foo/'

  test "$($BATS_TEST_DESCRIPTION '/Dev/../Home/Living Room')" = "/Home/Living Room"
  test "$($BATS_TEST_DESCRIPTION '/Soft Dev/../Home/Shop')" = "/Home/Shop"

  test "$($BATS_TEST_DESCRIPTION .)" = "."
  test "$($BATS_TEST_DESCRIPTION ./)" = "./"
}


@test "$lib/$base read-file-lines-while (default)" {
  read_file_lines_while test/var/nix_comments.txt || r=$?
  test "$line_number" = "5" || {
    diag "Line_Number: ${line_number}"
    diag "Status: $r"
    fail "Should have last line before first content line. "
  }
  test -z "$r"
}


@test "$lib/$base read-file-lines-while (negative)" {
  testf=test/var/nix_comments.txt
  r=; read_file_lines_while $testf \
    'echo "$line" | grep -q "not-in-file"' || r=$?
  test -n "$line_number"
  test -z "$r" -a "$r" != "0"
}


@test "$lib/$base read-file-lines-while header comments" {

  lib_load src

  testf=test/var/nix_comments.txt
  r=; read_file_lines_while $testf \
    'echo "$line" | grep -qE "^\s*#.*$"' || r=$?
  test "$line_number" = "4" || {
    diag "Line_Number: ${line_number}"
    diag "Status: $r"
    fail "Should have returned last header comment line. "
  }
  test -z "$r"

  header_comment $testf
  test "$line_number" = "4"
}


@test "$lib/$base line_count" {
  tmpd
  out=$tmpd/line_count

  printf "a\nb\nc\nd" >$out
  test "$(wc -l $out|awk '{print $1}')" = "3"
  test "$(line_count $out)" = "4"

  printf "a\nb\nc\nd\n" >$out
  test "$(wc -l $out|awk '{print $1}')" = "4"
  test "$(line_count $out)" = "4"

  echo abc >$out
  test "$(line_count $out)" = "1"
}


@test "$lib/$base filesize" {
  tmpd
  out=$tmpd/filesize
  printf "1\n2\n3\n4" >$out
  test -n "$(filesize "$out")" || bail
  diag "Filesize: $(filesize "$out")"
  test $(filesize "$out") -eq 7
}


@test "$lib get_uuid" {

  func_exists get_uuid
  run get_uuid
  test $status -eq 0
  test -n "${lines[*]}"
}


@test "$lib basename" {

  func_exists basenames
  run basenames .foo bar.foo
  { test_ok_nonempty && test "${lines[0]}" = "bar"
  } || stdfail 1
  run basenames ".foo .u-c .t" bar.t.u-c.foo
  { test_ok_nonempty && test "${lines[0]}" = "bar"
  } || stdfail 2
  run basenames ".t .u-c .foo" bar.t.u-c.foo
  { test_ok_nonempty && test "${lines[0]}" = "bar.t.u-c"
  } || stdfail 3
  run basenames ".tar .u-c .bz2 .gz" bar.u-c.tar foo.tar.bz2 baz.txt.gz
  { test_ok_nonempty && test "${lines[0]}" = "bar" &&
    test "${lines[1]}" = "foo.tar" &&
    test "${lines[2]}" = "baz.txt"
  } || stdfail 4.0
}


# Id: script-mpe/0.0.4-dev test/os-lib-spec.bats
