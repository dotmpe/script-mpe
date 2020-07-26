#!/usr/bin/env bats

load init
base=main
init

setup()
{
  BOX_INIT=1
  main_inc=$SHT_PWD/var/sh-src-main-mytest-funcs.sh
  . $main_inc
  export SCR_SYS_SH=
  sys_lib_load
}


@test "$base: std__help" {
  base=cmd
  cmd_man_1__sub="Bar1"
  #cmd__man_1_sub="Bar2"
  help_str=$(try_value sub man_1)
  test "$help_str" = "Bar1" || fail "$(try_value sub man_1)"
  std__help sub | grep -q $help_str || fail "$(std__help sub)"
}


@test "$base: try_help" {
  base=cmd
  cmd_spc__sub="sub|-b ARG"
  cmd_man_1__sub="Bar"
  run try_help 1 sub
  { test_ok_nonempty "  Bar"
  } || stdfail
  #test "${lines[*]}" = "$ cmd sub 	Bar Usage: 	cmd sub|-b ARG" &&
  #test "${lines[*]}" = "$ $base sub 	$cmd_man_1__sub Usage: 	$base $cmd_spc__sub"
}


#@test "$base: echo_help" {

@test "$base: echo_local" {
  base=
  test "$(echo_local abc)" = "__abc"
  test "$(echo_local abc 123)" = "_123__abc"
  test "$(echo_local abc 123 xyz)" = "xyz_123__abc"

  test "$(echo_local "" 123 xyz)" = "xyz_123"
  test "$(echo_local abc "" xyz)" = "xyz__abc"

  test "$(echo_local "abc123")" = "__abc123"
  #test "$(echo_local "abc123" "_")" = "_abc123"
  #test "$(echo_local "abc123" "" xxx)" = "_xxx__abc123"
  #test "$(echo_local abc123 _ xxx)" = "_xxx_abc123"

  test "$(echo_local b x)" = "_x__b"

  base=cmd
  test "$(echo_local var)" = "cmd__var"
}

@test "$base: try_value" {
  base=cmd
  cmd__var=var1
  test "$(try_value var)" = "var1"
  cmd_x__var=var2
  test "$(try_value var x)" = "var2"
}

@test "$base: try_local_var" {
  sh_isset myvar1 && stdfail 'unexpected myvar1' || true
  base=
  _x__b=123
  try_local_var myvar1 b x
  test "$myvar1" = "123"
  set | grep -q '^myvar1='
  #sh_isset myvar1 || stdfail "expected myvar1 ($SCR_SYS_SH)"
  SCR_SYS_SH=bash-sh sh_isset myvar1 || stdfail "expected myvar1 ($SCR_SYS_SH)"
  unset myvar1
}

@test "$base: try_spec" {
  cmd_spc__sub=spec1
  cmd2_spc__sub=spec2
  subcmd_pref=cmd
  base=cmd
  test "$(try_spec sub)" = spec1
  test "$(try_spec sub cmd2)" = spec2
  test "$(try_spec sub cmd)" = spec1
}

#@test "$base: try_func" {
#@test "$base: try_subcmd" {
#@test "$base: std-help" {

@test "$base: std-usage" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$base: std-commands" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$base: locate-name" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$base: get-cmd-{alias,func,func-name}" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}


@test "$base: get-cmd-func-name sets local ${1}_func from internal vars" {

  sh_isset test_name &&
    fail "Unexpected test_name= var in env ('$test_name')" ||
    true
  check_skipped_envs || TODO "envs $envs: implement for env"
}


@test "$base: get-subcmd-args,parse-subcmd-{valid-args,alias,opts}" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$base: main-load" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$base: main-debug" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$base: main" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}


# main / Clean Env


@test "$base: should source (functions) without polluting environment (with vars)" {
  unset verbosity

  check_isset()
  {
    run sh_isset $1
    test_nok_empty || stdfail "Unexpected $1=${!1} var in env"
  }

  # check for vars we use
  check_isset subcmd
  check_isset subcmd_name
  check_isset subcmd_pref
  check_isset subcmd_suf
  check_isset func
  check_isset func_name
  check_isset func_pref
  check_isset func_suf

  check_isset base
  check_isset scriptname
  check_isset script_name
  check_isset PREFIX
  check_isset SRC_PREFIX

  check_isset fn
  check_isset name
  check_isset flags
  check_isset pref
  check_isset suf
  check_isset verbosity
  check_isset silence
  check_isset tag
}


@test "$base: expect some *nix env" {

  sh_isset HOME || stdfail "Expected HOME= var in env"
}

@test "$base: expect the env for Box" {

  skip "not requiring exports for now.. but should test PREFIX, UCONF handling. ."
  sh_isset BOX_DIR || stdfail "Expected BOX_DIR= var in env"
}
