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

@test "info" {
  run ${bin} info
  test $status -eq 0
  test "${#lines[@]}" = "8"
}

@test "test-name" {
  run ${bin} test-name ./linux-network-interface-cards.py
  test $status -eq 0
  run ${bin} test-name "./Foo Bar Baz/"
  test $status -eq 0
  run ${bin} test-name "./Foo + Bar & Baz/"
  test $status -eq 0
  run ${bin} test-name "./(Foo) Bar [Baz]/"
  test $status -eq 0
}


