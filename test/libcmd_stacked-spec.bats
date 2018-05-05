#!/usr/bin/env bats

load init
load helper
base=libcmd_stacked_test.py
init


@test "${bin} -h " {
  run ./$base -h
  { test_ok_nonempty &&
    test ${#lines[@]} -gt 10 # lines of output (stdout+stderr)
  } || stdfail
}

@test "${bin} - No arguments should print config " {
  run ./$base
  { test_ok_nonempty &&
    test ${#lines[@]} -gt 3 # lines of output (stdout+stderr)
  } || stdfail
}
