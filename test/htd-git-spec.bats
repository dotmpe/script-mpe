#!/usr/bin/env bats

load init
base=htd-git
init

@test "htd git - help" {
  run htd help git
  test_ok_nonempty || stdfail
}
