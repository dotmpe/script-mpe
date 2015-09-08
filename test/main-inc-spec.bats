#!/usr/bin/env bats

load helper
load main.inc

init_lib
source $lib/util.sh
source $lib/main.sh


# main / Incr-C

@test "$lib/main incr-c increments var c, output is clean" {

  var_isset c && test -z "Unexpected c= var in env" || noop

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

# main / Clean Env

@test "$lib/main should source (functions) without polluting environment (with vars)" {

  # check for vars we use
  var_isset cmd && test -z "Unexpected cmd= var in env" || noop
  var_isset cmd_name && test -z "Unexpected cmd_name= var in env" || noop
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

@test "$lib/main get-cmd-func-name sets local ${1}_func from internal vars" {

  var_isset test_name && test -z "Unexpected test_name= var in env" || noop

}

# vim:ft=sh:
