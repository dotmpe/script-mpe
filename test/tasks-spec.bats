#!/usr/bin/env bats

load init
base=tasks.py

setup()
{
  init 0 && load stdtest
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
