#!/usr/bin/env bats

load helper
base=env-deps.lib
init

@test "${lib}/${base} - env-deps loads" {

  lib_load env-deps
  func_exists boxenv_dep_puml
  func_exists boxenv_git
  TODO "proper testing"
}

