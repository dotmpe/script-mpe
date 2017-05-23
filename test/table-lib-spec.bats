#!/usr/bin/env bats

load helper
base=table.lib

init
. $lib/util.sh


setup()
{
  lib_load table
}


@test "$bin - fixed_table_hd_offset returns column offset given headers" {

  cd $pwd
  #. $lib/htd load-ext
  #. $lib/table.lib.sh

  htd_rules=$BATS_TMPDIR/htd-rules.tab
  echo "#CMD FOO BAR BAZ BAM" >$htd_rules

  run fixed_table_hd_offset CMD CMD $htd_rules
  test $status -eq 0
  test "${lines[*]}" = "0"

  run fixed_table_hd_offset FOO CMD $htd_rules
  test $status -eq 0
  test "${lines[*]}" = "5"

  run fixed_table_hd_offset BAR CMD $htd_rules
  test $status -eq 0
  test "${lines[*]}" = "9"
}

@test "fixed-table-hd: returns fields from first comment-line" {
  run fixed_table_hd test/var/table-1.tab
  test $status -eq 0
  test "${lines[*]}" = "FOO BAR BAZ"
}

@test "fixed-table: reads preformatted, named columns to rows of values" {
  run fixed_table test/var/table-1.tab FOO BAR BAZ
  {
    test $status -eq 0 &&
    test "${lines[0]}" = ' FOO="123.5"  BAR="-ABC"  BAZ="a b c"  line="123.5      -ABC           a b c" ' &&
		test "${lines[1]}" = ' FOO="456.9"  BAR="-DEF"  BAZ="d e f"  line="456.9      -DEF           d e f" ' &&
		test "${lines[2]}" = ' FOO="789.1"  BAR="-XYZ"  BAZ="x y z"  line="789.1      -XYZ           x y z" '
  } || stdfail
}

@test "fixed-table: reads preformatted, named columns to rows of values" {
  run fixed_table test/var/table-1.tab
  {
    test $status -eq 0 &&
    test "${lines[0]}" = ' FOO="123.5"  BAR="-ABC"  BAZ="a b c"  line="123.5      -ABC           a b c" ' &&
		test "${lines[1]}" = ' FOO="456.9"  BAR="-DEF"  BAZ="d e f"  line="456.9      -DEF           d e f" ' &&
		test "${lines[2]}" = ' FOO="789.1"  BAR="-XYZ"  BAZ="x y z"  line="789.1      -XYZ           x y z" '
  } || stdfail
}

