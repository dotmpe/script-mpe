#!/usr/bin/env bats

base=stattab.lib
load init

setup()
{
  init &&
  tmpd && STATUSDIR_ROOT=$tmpd &&
  lib_load stattab date build-htd setup-sh-tpl && build_init
}

@test "$base: descr" {
  local verbosity=3
  stattab_entry_env
  sttab_stat="-"
  sttab_ctime=1539470160
  run stattab_descr
  { test_ok_nonempty 2 && test_lines "-" "20181014-0036+02"
  } || stdfail
}

@test "$base: fields entry" {
  local verbosity=3
  stattab_entry_env
  sttab_id=none
  sttab_ctime=1539470160
  run stattab_entry_fields
  { test_ok_nonempty 3 && test_lines "-" "20181014-0036+02" "none"
  } || stdfail 1.

  sttab_id=
  run stattab_entry_fields test-some-fields
  { test_ok_nonempty 3 && test_lines "-" "20[0-9][0-9][0-9][0-9]*-[0-9]*" "test-some-fields"
  } || stdfail 2.
}

@test "$base: defaults entry" {
  run stattab_entry_defaults
  test_ok_empty || stdfail
}

@test "$base: exists" {
  run stattab_entry_exists "test-stat-1"
  test_nok_empty || stdfail A.

  test_tpl="test/var/stattab/stattab-tpl1.sh"
  setup_sh_tpl "$test_tpl" "" "$tmpd"
  run stattab_entry_exists "test-stat"
  test_nok_empty || stdfail B.1.
  run stattab_entry_exists "test-stat-1"
  test_ok_empty || stdfail B.2.
}

@test "$base: entry" {
  run stattab_entry "test-stat-1"
  test_nok_empty || stdfail A.

  test_tpl="test/var/stattab/stattab-tpl1.sh"
  setup_sh_tpl "$test_tpl" "" "$tmpd"
  run stattab_entry "test-stat-1"
  test_ok_empty || stdfail B.
}

@test "$base: new entry" {
  run stattab_init test-stat
  { test_ok_nonempty &&
    stattab_entry_exists "test-stat"
  } || stdfail
}

@test "$base: update entry" {
  stattab_entry_env
  sttab_src=none
  stattab_load test-me
  TODO
  #run sttab_tags "@Std"
  #test_ok_nonempty || stdfail
}
