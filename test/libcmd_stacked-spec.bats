#!/usr/bin/env bats

load helper
base=libcmd_stacked.py

init


@test "${bin} -h " {
  run python $bin -h
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
  test "${#lines[@]}" -gt "10" # lines of output (stdout+stderr)
}

@test "${bin} - No arguments should print config " {
  run python $bin
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
#FIXME: SA warning on Linux
#test "${#lines[@]}" = "3" # lines of output (stdout+stderr)
}

