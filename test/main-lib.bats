#!/usr/bin/env bats

load init
base=main.lib
init

setup()
{
  true #lib_load os-htd sys-htd str main && lib_init
}

@test "$base: {push,pop}-cwd baseline" {

# FIXME CWD
  CWD=

  test "$PWD" = "$BATS_CWD" || fail 0.1

  run push_cwd
  test_ok_empty || stdfail 1.1

  _run() { push_cwd && pwd; }; run _run
  test_ok_lines "$BATS_CWD" || stdfail 1.2

  run pop_cwd
  test_ok_empty || stdfail 2.1
  test "$PWD" = "$BATS_CWD" || fail 2.2
}

@test "$base: {push,pop}-cwd moves to subdir and returns" {

  CWD=

  RCWD=test

  run push_cwd
  test_ok_empty || stdfail

  _run() { push_cwd && pwd; }; run _run
  test_ok_lines "$BATS_CWD/test" || stdfail 1.2

  run pop_cwd
  test_ok_empty || stdfail
}

@test "$base: {push,pop}-cwd moves two subdirs, and returns" {

  _run() { push_cwd test && push_cwd helper && pwd;
  }; run _run
  test_ok_lines "$BATS_CWD/test/helper" || stdfail 1

  _run() { push_cwd test && push_cwd helper && pop_cwd && pop_cwd && pwd;
  }; run _run
  test_ok_lines "$BATS_CWD" || stdfail 2
}
