#!/h usr/bin/env bats

base=setup-sh-tpl.lib
load init

setup()
{
  init 0 &&
  lib_load std setup-sh-tpl &&
  load assert
}

@test "$base: setup-sh-tpl: simple files: 1. parts" {

  run setup_sh_tpl_basevar ".../.../setup-sh-tpl-1.sh"
  test_ok_nonempty "setup_sh_tpl_1_" || stdfail 1.1.1

  # Test template part and setup-sh-tpl functions
  verbosity=3
  . $SHT_PWD/var/build-lib/setup-sh-tpl-1.sh

  run setup_sh_tpl_name_index "File Name" setup_sh_tpl_
  test_ok_nonempty "1" || stdfail 1.2.1

  run setup_sh_tpl_name_index "No Such Name" setup_sh_tpl_
  test_nok_empty || stdfail 1.2.2

  # Setup one file and sub-dir file

  run setup_file_from_sh_tpl 1 setup_sh_tpl_
  test_ok_empty || stdfail 1.3.1.1
  assert_file_exist "File Name"
  assert_file_not_exist "Other Path"
  # NOTE: trailing line is giving problem with shell-str here
  assert_equal "$(cat "File Name")" "$(echo "$setup_sh_tpl__1__contents")"
  rm "File Name" 

  run setup_sh_tpl_name "File Name" setup_sh_tpl_
  test_ok_empty || stdfail 1.3.1.2
  assert_file_exist "File Name"
  assert_equal "$(cat "File Name")" "$(echo "$setup_sh_tpl__1__contents")"
  assert_file_not_exist "Other Path"
  rm "File Name" 

  run setup_sh_tpl_name "Other Path/*" setup_sh_tpl_
  test_ok_empty || stdfail 1.3.2
  assert_file_not_exist "File Name"
  assert_file_exist "Other Path/File Name"
  assert_equal "$(cat "Other Path/File Name")" "$(echo "$setup_sh_tpl__2__contents")"
  rm -r "Other Path"
}

@test "$base: setup-sh-tpl: simple files in subdir: 2. entire tpl 1" {

  # XXX: see test-state req. trueish "$setup_sh_tpl_lib_test_1" || skip
  tmpd

  # Test entire templae
  run setup_sh_tpl "$SHT_PWD/var/build-lib/setup-sh-tpl-1.sh" setup_sh_tpl_ "$tmpd"
  test_ok_nonempty || stdfail 2.
  assert_file_exist "$tmpd/File Name"
  assert_file_exist "$tmpd/Other Path/File Name"

  . $SHT_PWD/var/build-lib/setup-sh-tpl-1.sh
  assert_equal "$(cat "$tmpd/File Name")" "$(echo "$setup_sh_tpl__1__contents")"
  assert_equal "$(cat "$tmpd/Other Path/File Name")" "$(echo "$setup_sh_tpl__2__contents")"

  rm -rf "$tmpd"
}
