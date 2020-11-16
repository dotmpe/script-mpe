#!/usr/bin/env bats

base=scrtab.lib
load init
init

setup()
{
  load stdtest extra && tmpd scrtab-lib-spec && STATUSDIR_ROOT=$tmpd &&
  mkdir -p "$tmpd/index" &&
  lib_require std src statusdir package scrtab build-htd setup-sh-tpl \
    str-htd date date-htd && lib_init scrtab && build_init
}

teardown()
{
  rm -rf "$tmpd"
}

@test "$base: echoes entry" {
  local verbosity=3

  scrtab_entry_env_reset
  scr_id=test-some-fields
  scr_ctime=1539470160
  scr_mtime=1539470160
  run scrtab_init
  test_ok_nonempty "- 20181014-0036+02 20181014-0036+02 $scr_id " || stdfail

  scr_scr=whoami
  scr_src=none
  scr_mtime=
  run scrtab_init
  test_ok_nonempty "- 20181014-0036+02 - $scr_id \`\`$scr_scr\`\` " || stdfail
}

@test "$base: scr ctx" {
  run scrtab_entry_ctx
  test_ok_empty || stdfail
}

@test "$base: scr tags" {
  scrtab_entry_env_reset
  scr_src=none
  scrtab_env_prep test-me
  run scr_tags "@Std"
  test_ok_empty || stdfail
}

@test "$base: scr defaults" {
  skip
  run scrtab_entry_defaults  "@Std"
  test_ok_empty || stdfail
}
