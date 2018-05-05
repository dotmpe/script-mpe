#!/usr/bin/env bats

load init
base=table.lib

init
#. $lib/util.sh


setup()
{
  lib_load table
}


@test "$base - fixed_table_hd_offset: returns column offset given headers" {

  cd $pwd

  htd_rules=$BATS_TMPDIR/htd-rules.tab
  echo "#CMD FOO BAR BAZ BAM" >$htd_rules

  run fixed_table_hd_offset CMD CMD $htd_rules
  { test $status -eq 0 &&
    test "${lines[*]}" = "0"
  } || stdfail

  run fixed_table_hd_offset FOO CMD $htd_rules
  { test $status -eq 0 &&
    test "${lines[*]}" = "5"
  } || stdfail

  run fixed_table_hd_offset BAR CMD $htd_rules
  { test $status -eq 0 &&
    test "${lines[*]}" = "9"
  } || stdfail
}

@test "$base - fixed-table-hd-ids: returns fields from first comment-line" {
  run fixed_table_hd_ids test/var/table-1.tab
  { test $status -eq 0 &&
    test "${lines[*]}" = "FOO BAR BAZ"
  } || stdfail
}

@test "$base - fixed-table-hd: returns fields from first comment-line" {
  run fixed_table_hd test/var/table-1.tab
  { test $status -eq 0 &&
    test "$(echo ${lines[*]})" = "FOO BAR BAZ"
  } || stdfail
}

@test "$base - fixed-table: reads preformatted, named columns to rows of values" {
  run fixed_table test/var/table-1.tab FOO BAR BAZ
  {
    test $status -eq 0 &&
    test "${lines[0]}" = ' FOO=\"123.5\"  BAR=\"-ABC\"  BAZ=\"a b c\"  row_nr=1  line=\"123.5      -ABC           a b c\" ' &&
	test "${lines[1]}" = ' FOO=\"456.9\"  BAR=\"-DEF\"  BAZ=\"d e f\"  row_nr=2  line=\"456.9      -DEF           d e f\" ' &&
	test "${lines[2]}" = ' FOO=\"789.1\"  BAR=\"-XYZ\"  BAZ=\"x y z\"  row_nr=3  line=\"789.1      -XYZ           x y z\" '
  } || stdfail
}

@test "fixed-table: reads preformatted, named columns to rows of values" {
  run fixed_table test/var/table-1.tab
  {
    test $status -eq 0 &&
    test "${lines[0]}" = ' FOO=\"123.5\"  BAR=\"-ABC\"  BAZ=\"a b c\"  row_nr=1  line=\"123.5      -ABC           a b c\" ' &&
	test "${lines[1]}" = ' FOO=\"456.9\"  BAR=\"-DEF\"  BAZ=\"d e f\"  row_nr=2  line=\"456.9      -DEF           d e f\" ' &&
	test "${lines[2]}" = ' FOO=\"789.1\"  BAR=\"-XYZ\"  BAZ=\"x y z\"  row_nr=3  line=\"789.1      -XYZ           x y z\" '
  } || stdfail
}
