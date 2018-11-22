#!/usr/bin/env bats

base=os.lib
load init

setup()
{
  init &&
  lib_load sys &&

  # var/table-1.tab: File with 5 comment lines, 3 rows, 1 empty and 1 blank (ws)
  testf1="test/var/table-1.tab" &&

  # Several blocks of comments and two content lines, 4 empty lines (no ws.)
  testf2=test/var/nix_comments.txt
}


@test "$base: read-nix-style-file strips blank and octothorp comment lines" {
  run read_nix_style_file "$testf1"
  { test_ok_nonempty 3
  } || stdfail
}

@test "$base: lines-slice [First-Line] [Last-Line] \$testf1" {

  # Test first two args
  run lines_slice "" "" "$testf1"
  { test_ok_nonempty 9 # BATS removes empty lines, but not blank lines
  } || stdfail 1.1.
  run lines_slice 8 10 "$testf1"
  { test_ok_nonempty 3 && # lines-slice does not filter comments/blanks
    test_lines \
        '789.1      -XYZ           x y z' \
        '   ' \
        '#:vim:ft=todo.txt:'

  } || stdfail 1.2.
  run lines_slice "" 9 "$testf1"
  { test_ok_nonempty 8 # BATS removes empty, really is 9 here.
  } || stdfail 1.3.1.
  run lines_slice 6 "" "$testf1"
  { test_ok_nonempty 5
  } || stdfail 1.3.2.
}

@test "$base: lines-slice [First-Line] [Last-Line] - (stdin)" {

  __test__() { cat "$3" | lines_slice "$@" -; };
  # Test first two args gain for stdin.
  run __test__ "" "" "$testf1"
  { test_ok_nonempty 9 # BATS removes empty lines, but not blank lines
  } || stdfail 1.1.
  run __test__ 8 10 "$testf1"
  { test_ok_nonempty 3 && # lines-slice does not filter comments/blanks
    test_lines \
        '789.1      -XYZ           x y z' \
        '   ' \
        '#:vim:ft=todo.txt:'

  } || stdfail 1.2.
  run __test__ "" 9 "$testf1"
  { test_ok_nonempty 8 # BATS removes empty, really is 9 here.
  } || stdfail 1.3.1.
  run __test__ 6 "" "$testf1"
  { test_ok_nonempty 5
  } || stdfail 1.3.2.
}


@test "$base: read-lines{,-while} (default)" {

  load assert

  # Pipeline setup testing lines-while directly
  cat "$testf2" | {
    r= ; lines_while 'echo "$line" | grep -qE "^\s*#.*$"' || r=$?

  # Should point last line before first content line.
    assert_equal "$r" ""
    assert_equal "$line_number" "4"
  }

  # Use existing pipeline to capture line-number
  r= ; read_lines_while "$testf2" 'echo "$line" | grep -qE "^\s*#.*$"' || r=$?

  # Idem.
  test -z "$r"
  assert_equal "$line_number" "4"
}


@test "$base: read-lines{,-while} (negative)" {

  load assert

  # Pipeline setup testing lines-while directly
  cat "$testf2" | {
    r= ; lines_while 'echo "$line" | grep -q "^not-in-file$"' || r=$?

  # Should point to no line, non-zero
    assert_equal "$line_number" "0"
    assert_equal "$r" "1"
  }
  
  # Use existing pipeline to capture line-number
  r= ; read_lines_while "$testf2" 'echo "$line" | grep -q "^not-in-file$"' || r=$?

  # Idem.
  assert_equal "$line_number" "0"
  assert_equal "$r" "1"
}

@test "$base: read-lines{,-while} (negative II)" {

  load assert

  # Pipeline setup testing lines-while directly
  cat "$testf2" | {
    r= ; lines_while 'echo "$line" | grep -q "^.*$"' || r=$?

  # Should point to last line
    assert_equal "$r" ""
    assert_equal "$line_number" "13"
  }

  # Use existing pipeline to capture line-number
  r= ; read_lines_while "$testf2" 'echo "$line" | grep -q "^.*$"' || r=$?

  # Should point last line before first content line.
  assert_equal "$r" ""
  assert_equal "$line_number" "13"
}


@test "$base: line_count" {
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


@test "$base: filesize" {
  tmpd
  out=$tmpd/filesize
  printf "1\n2\n3\n4" >$out
  test -n "$(filesize "$out")" || bail
  diag "Filesize: $(filesize "$out")"
  test $(filesize "$out") -eq 7
}


@test "$base: get_uuid" {

  func_exists get_uuid
  run get_uuid
  test $status -eq 0
  test -n "${lines[*]}"
}


@test "$base: basename" {

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


@test "$base: short" {

  TODO "FIXME: short is far to slow"

  func_exists short
  run short
  test $status -eq 0 || fail "${lines[*]}"

  fnmatch "$HOME*" "$lib" && {
    fnmatch "~/*" "${lines[*]}"
  } || {
    test "$lib" = "${lines[*]}"
  }
}

@test "$base: ziplists" {
  __test__() { {
      seq 0 9
      seq 10 19
    } | ziplists 10 ; }
  run __test__
  { test_ok_nonempty 10 && test_lines "0	10" "1	11" "2	12"
  } || stdfail
}

# Id: script-mpe/0.0.4-dev test/os-lib-spec.bats
