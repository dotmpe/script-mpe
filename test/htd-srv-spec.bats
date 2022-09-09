#!/usr/bin/env bats

base=htd
load init
init


@test "$bin srv: default (no args) runs without errors" {
  run $bin srv
  test "$status" = "0"
}

@test "$bin srv -names" {
  run $bin srv -names
  test "$status" = "0"
}

@test "$bin srv -instances" {
  run $bin srv -instances
  test "$status" = "0"
}

@test "$bin srv -paths" {
  run $bin srv -paths
  test "$status" = "0"
}

@test "$bin srv -vpaths" {
  run $bin srv -vpaths
  test "$status" = "0"
}


@test "$bin srv: every disk is a volume" {
  TODO test
}

@test "$bin srv: every -local is a symlink, there a corresponding fully qualified name" {
  TODO test
}

@test "$bin srv: for every name a -local is set" {
  TODO test
}


@test "$bin srv check" {
  run $bin srv check
  test "$status" = "0"
}

@test "$bin srv update" {
  run $bin srv update
  test "$status" = "0"
}

@test "$bin srv init src" {
  run $bin srv init src
  test "$status" = "0"
}
