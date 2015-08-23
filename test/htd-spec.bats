#!/usr/bin/env bats

bin=htd

load helper

@test "no arguments no-op" {
  run ${bin}
  test $status -eq 1
  test "${#lines[@]}" = "4"
}

@test "help" {
  run ${bin} help
  test $status -eq 0
}

@test "home" {
  run ${bin} home
  test $status -eq 0
  test -n "$HTDIR" || HTDIR="$(echo ~/htd)"
  test "${lines[0]}" = "$HTDIR"
}


