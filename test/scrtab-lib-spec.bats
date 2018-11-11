#!/usr/bin/env bats

base=scrtab.lib
load init
init

setup()
{
  tmpd && STATUSDIR_ROOT=$tmpd &&
  lib_load scrtab date build setup-sh-tpl && build_init
}

@test "$base: entry fields" {
  local verbosity=3
  scrtab_entry_env
  scr_src=none
  scr_ctime=1539470160
  run scrtab_entry_fields test-some-fields "$@"
  test_ok_nonempty "- 20181014-0036+02 -" || stdfail
}

@test "$base: scr ctx" {
  run scrtab_entry_ctx
  test_ok_nonempty || stdfail
}

@test "$base: scr tags" {
  scrtab_entry_env
  scr_src=none
  scrtab_load test-me
  #run scr_tags "@Std"
  #test_ok_nonempty || stdfail
}

@test "$base: scr defaults" {
  skip
  run scrtab_entry_defaults  "@Std"
  test_ok_nonempty || stdfail
}
