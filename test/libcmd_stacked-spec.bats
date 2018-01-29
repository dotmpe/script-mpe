#!/usr/bin/env bats

load helper
bin=libcmd_stacked_test.py

init


@test "${bin} -h " {
  run ./$bin -h
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
  test "${#lines[@]}" -gt "10" # lines of output (stdout+stderr)
}

@test "${bin} - No arguments should print config " {
  run ./$bin
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
  test "${#lines[@]}" = "3" # lines of output (stdout+stderr)
}
