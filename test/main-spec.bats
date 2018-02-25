#!/usr/bin/env bats

base=main
load init
load main.inc

init

BOX_INIT=1


# main / Incr-C


@test "$lib/main incr x (amount): increments var x, output is clean" {

  var_isset x && fail "Unexpected 'x' var in env (x=$x)" || noop

  incr x 3
  test $? -eq 0
  #test -z "${lines[*]}"

  test -n "$x"
  test $x -eq 3

  incr x 1
  test $x -eq 4

  unset x
}


@test "$lib/main incr-c: increments var c, output is clean" {

  var_isset c && fail "Unecpected 'c' var in env (c=$c)" || noop

  incr_c
  test $? -eq 0
  test -z "${lines[*]}"
  test -n "$c"
  test $c -eq 1
  unset c

  incr_c && incr_c && incr_c
  test -z "${lines[*]}"
  test $? -eq 0
  test $c -eq 3
  unset c
}


@test "$lib/main std__help" {
  base=cmd
  cmd_man_1__sub="Bar1"
  #cmd__man_1_sub="Bar2"
  help_str=$(try_value sub man_1)
  test "$help_str" = "Bar1" || fail "$(try_value sub man_1)"
  std__help sub | grep -q $help_str || fail "$(std__help sub)"
}


@test "$lib/main try_help" {
  base=cmd
  cmd_spc__sub="sub|-b ARG"
  cmd_man_1__sub="Bar"
  run try_help 1 sub
  test_ok_nonempty || stdfail 
  test "${lines[*]}" = "$ cmd sub 	Bar Usage: 	cmd sub|-b ARG"
  test "${lines[*]}" = "$ $base sub 	$cmd_man_1__sub Usage: 	$base $cmd_spc__sub"
}


#@test "$lib/main echo_help" {

@test "$lib/main echo_local" {
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

@test "$lib/main try_value" {
  base=cmd
  cmd__var=var1
  test "$(try_value var)" = "var1"
  cmd_x__var=var2
  test "$(try_value var x)" = "var2"
}

@test "$lib/main try_local_var" {
  var_isset myvar1 && test -z 'unexpected myvar1' || noop
  base=
  _x__b=123
  try_local_var myvar1 b x
  test "$myvar1" = "123"
  var_isset myvar1 || test -z 'expected myvar1'
  unset myvar1
}

@test "$lib/main try_spec" {
  cmd_spc__sub=spec1
  cmd2_spc__sub=spec2
  subcmd_pref=cmd
  base=cmd
  test "$(try_spec sub)" = spec1
  test "$(try_spec sub cmd2)" = spec2
  test "$(try_spec sub cmd)" = spec1
}

#@test "$lib/main try_func" {
#@test "$lib/main try_subcmd" {
#@test "$lib/main std-help" {

@test "$lib/main std-usage" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$lib/main std-commands" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$lib/main locate-name" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$lib/main get-cmd-{alias,func,func-name}" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}


@test "$lib/main get-cmd-func-name sets local ${1}_func from internal vars" {

  var_isset test_name && 
    fail "Unexpected test_name= var in env ('$test_name')" ||
    noop
  check_skipped_envs || TODO "envs $envs: implement for env"
}


@test "$lib/main get-subcmd-args,parse-subcmd-{valid-args,alias,opts}" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$lib/main main-load" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$lib/main main-debug" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}

@test "$lib/main main" {

  check_skipped_envs || TODO "envs $envs: implement for env"
}


# main / Clean Env


@test "$lib/main should source (functions) without polluting environment (with vars)" {

  # check for vars we use
  var_isset subcmd && test -z "Unexpected subcmd= var in env" || noop
  var_isset subcmd_name && test -z "Unexpected subcmd_name= var in env" || noop
  var_isset subcmd_pref && test -z "Unexpected subcmd_pref= var in env" || noop
  var_isset subcmd_suf && test -z "Unexpected subcmd_suf= var in env" || noop
  var_isset func && test -z "Unexpected func= var in env" || noop
  var_isset func_name && test -z "Unexpected func_name= var in env" || noop
  var_isset func_pref && test -z "Unexpected func_pref= var in env" || noop
  var_isset func_suf && test -z "Unexpected func_suf= var in env" || noop
  var_isset base && test -z "Unexpected base= var in env" || noop
  var_isset scriptname && test -z "Unexpected scriptname= var in env" || noop
  var_isset script_name && test -z "Unexpected script_name= var in env" || noop

  var_isset PREFIX && test -z "Unexpected PREFIX= var in env" || noop
  var_isset SRC_PREFIX && test -z "Unexpected SRC_PREFIX= var in env" || noop

  var_isset fn && test -z "Unexpected fn= var in env" || noop
  var_isset name && test -z "Unexpected name= var in env" || noop
  var_isset flags && test -z "Unexpected flags= var in env" || noop
  var_isset pref && test -z "Unexpected pref= var in env" || noop
  var_isset suf && test -z "Unexpected suf= var in env" || noop
  var_isset verbosity && test -z "Unexpected verbosity= var in env" || noop
  var_isset silence && test -z "Unexpected silence= var in env" || noop
  var_isset tag && test -z "Unexpected tag= var in env" || noop
}


@test "$lib/main expect some *nix env" {

  var_isset HOME || test -z "Expected HOME= var in env"
}

@test "$lib/main expect the env for Box" {

  skip "not requiring exports for now.. but should test PREFIX, UCONFDIR handling. ."
  var_isset BOX_DIR || test -z "Expected BOX_DIR= var in env"
}



