#!/usr/bin/env bats

base=table.lib
load init
init
load assert

setup()
{
  lib_load table &&
  testf1=test/var/table-1.tab
}


@test "$base: fixed-table-hd-ids: returns fields from first comment-line" {
  run fixed_table_hd_ids $testf1
  { test $status -eq 0 && test "${lines[*]}" = "FOO BAR BAZ"; } || stdfail
}

@test "$base: fixed_table_hd_offset: returns column offset given headers" {

  htd_rules=$BATS_TMPDIR/htd-rules.tab
  echo "#CMD FOO BAR BAZ BAM" >$htd_rules
  run fixed_table_hd_offset CMD CMD $htd_rules
  { test_ok_nonempty && test_lines "0" ; } || stdfail 1.1.1
  run fixed_table_hd_offset FOO CMD $htd_rules
  { test_ok_nonempty && test_lines "5" ; } || stdfail 1.1.2
  run fixed_table_hd_offset BAR CMD $htd_rules
  { test_ok_nonempty && test_lines "9" ; } || stdfail 1.1.3
  
  echo "# CMD FOO BAR BAZ BAM" >$htd_rules
  run fixed_table_hd_offset CMD CMD $htd_rules
  { test_ok_nonempty 1 && test_lines "0" ; } || stdfail 1.2.1
  run fixed_table_hd_offset FOO CMD $htd_rules
  { test_ok_nonempty 1 && test_lines "6" ; } || stdfail 1.2.2
  run fixed_table_hd_offset BAR CMD $htd_rules
  { test_ok_nonempty 1 && test_lines "10" ; } || stdfail 1.2.3

  echo "# CMD  FOO BAR BAZ BAM" >$htd_rules
  run fixed_table_hd_offset CMD CMD $htd_rules
  { test_ok_nonempty 1 && test_lines "0" ; } || stdfail 1.3.1
  run fixed_table_hd_offset FOO CMD $htd_rules
  { test_ok_nonempty 1 && test_lines "7" ; } || stdfail 1.3.2
  run fixed_table_hd_offset BAR CMD $htd_rules
  { test_ok_nonempty 1 && test_lines "11" ; } || stdfail 1.3.3

  # Test var/table-1
  run fixed_table_hd_offset FOO FOO $testf1
  { test_ok_nonempty && test_lines "0" ; } || stdfail 3.1
  run fixed_table_hd_offset BAR FOO $testf1
  { test_ok_nonempty && test_lines "11" ; } || stdfail 3.2
  run fixed_table_hd_offset BAZ FOO $testf1
  { test_ok_nonempty && test_lines "26" ; } || stdfail 3.3
}

@test "$base: fixed-table-hd-offsets" {
  run fixed_table_hd_offsets $testf1 FOO BAR BAZ
  { test_ok_nonempty 3 && test_lines "0" "11" "26" ; } || stdfail 1.
}

@test "$base: fixed-table-hd-cuts" {
  run fixed_table_hd_cuts $testf1 FOO BAR BAZ
  { test_ok_nonempty 3 && test_lines \
        "FOO -c1-11" \
        "BAR -c12-26" \
        "BAZ -c27-" ;
  } || stdfail 1.
}
  
@test "$base: fixed-table: reads preformatted, named columns to rows of values" {
  rm $testf1.cuthd || true
  run fixed_table $testf1 FOO BAR BAZ
  {
    test $status -eq 0 &&
    test "${lines[0]}" = ' FOO=\"123.5\"  BAR=\"-ABC\"  BAZ=\"a b c\"  row_nr=1  line=\"123.5      -ABC           a b c\" ' &&
	test "${lines[1]}" = ' FOO=\"456.9\"  BAR=\"-DEF\"  BAZ=\"d e f\"  row_nr=2  line=\"456.9      -DEF           d e f\" ' &&
	test "${lines[2]}" = ' FOO=\"789.1\"  BAR=\"-XYZ\"  BAZ=\"x y z\"  row_nr=3  line=\"789.1      -XYZ           x y z\" '
  } || stdfail
  rm $testf1.cuthd || true
}

@test "fixed-table: reads preformatted, named columns to rows of values" {
  run fixed_table $testf1
  {
    test $status -eq 0 &&
    test "${lines[0]}" = ' FOO=\"123.5\"  BAR=\"-ABC\"  BAZ=\"a b c\"  row_nr=1  line=\"123.5      -ABC           a b c\" ' &&
	test "${lines[1]}" = ' FOO=\"456.9\"  BAR=\"-DEF\"  BAZ=\"d e f\"  row_nr=2  line=\"456.9      -DEF           d e f\" ' &&
	test "${lines[2]}" = ' FOO=\"789.1\"  BAR=\"-XYZ\"  BAZ=\"x y z\"  row_nr=3  line=\"789.1      -XYZ           x y z\" '
  } || stdfail
  rm $testf1.cuthd || true
}
