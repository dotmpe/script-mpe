#!/usr/bin/env bats

load init
base=argv.lib
init

setup()
{
  lib_load argv
}

@test "$base: - lib loads" {
  func_exists test_exists
  func_exists test_dir
  func_exists test_file
  func_exists test_glob
  func_exists arg_vars
  func_exists argv_vars
  func_exists req_bin
	func_exists req_path_arg
	func_exists req_file_arg
	func_exists req_dir_arg
	func_exists req_cdir_arg
	func_exists req_file_env
	func_exists req_dir_env
	func_exists opt_args
	func_exists define_var_from_opt
}

@test "$base: - arg-vars" {
  run arg_vars "foo bar el_baz" 1 b false
  {
    test_ok_nonempty &&
    test "${lines[*]}" = " foo=1 bar=b el_baz=false"
  } || stdfail
}
