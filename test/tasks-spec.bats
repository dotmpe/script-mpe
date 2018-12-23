#!/usr/bin/env bats

base=tasks.py

#&& load stdtest
setup()
{
  load init || $INIT_LOG "error" "" "load-init" "" 1
  #verbosity=7
  ##test -z "$lib_loaded" || return 105
  #test -n "$script_util" || script_util=$(pwd -P)/tools/sh
  ##test -d "$script_util" || return 103 # NOTE: sanity
  #test_env_load || return
  #test_env_init || return
  #load stdtest

  load_init_bats || err_ "error" "$?" "env-init" "$BATS_TEST_NAME" 1
  #init 0 || err_ "error" "$?" "env-init" "$BATS_TEST_NAME" 1
  #init_sh_libs="$1" . ./tools/sh/init.sh &&
}

@test "$base: baseline" {

  run tasks.py --help
  { test_ok_nonempty && test_lines "*Usage*"; } || stdfail 1.

  run tasks.py --version
  test_ok_nonempty || stdfail 2.

  DEBUG= verbosity=0 \
  run tasks.py --version
  test_ok_nonempty 1 || stdfail 2.1.

  run tasks.py help
  { test_ok_nonempty && test_lines "*info*" "*help*"; } || stdfail 3.

  run tasks.py info
  test_ok_nonempty || stdfail 4.
}

@test "$base: list-issues" {

  run tasks.py list-issues
  test_ok_nonempty
}

@test "$base: read-issues" {

  run tasks.py read-issues
  test_ok_nonempty
}

@test "$base: parse-list" {

  run tasks.py read-issues
  test_ok_nonempty
}
