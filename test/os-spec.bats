#!/usr/bin/env bats

base=htd
load helper
init
source $lib/util.sh
source $lib/str.lib.sh


version=0.0.2 # script-mpe

@test "$bin normalize-relative" {

  check_skipped_envs travis jenkins || \
    skip "$BATS_TEST_DESCRIPTION not running at Linux (Travis)"

  test -n "$TERM" || export TERM=dumb
  
  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/.')" = 'Foo/Bar'
  test "$($BATS_TEST_DESCRIPTION 'Foo/Bar/./')" = 'Foo/Bar/'

#  run $BATS_TEST_DESCRIPTION 'Foo/Bar/../'
#  test ${status} -eq 0
#  test "${lines[*]}" = 'Foo/' || fail "Out: ${lines[*]}"

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

@test "$bin read-file-lines-while (default)" {
  read_file_lines_while test/var/nix_comments.txt || r=$?
  test "$line_number" = "5" || {
    diag "Line_Number: ${line_number}"
    diag "Status: $r"
    fail "Should have last line before first content line. "
  }
  test -z "$r"
}

@test "$bin read-file-lines-while (negative)" {
  testf=test/var/nix_comments.txt
  r=; read_file_lines_while $testf \
    'echo "$line" | grep -q "not-in-file"' || r=$?
  test -n "$line_number"
  test -z "$r" -a "$r" != "0"
}

@test "$bin read-file-lines-while header comments" {
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


