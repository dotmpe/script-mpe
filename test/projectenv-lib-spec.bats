#!/usr/bin/env bats

load helper
base=projectenv.lib
init

@test "${lib}/${base} - projectenv loads" {

  lib_load projectenv
  test -n "$build_errors"
  test ! -e "$build_errors"
  func_exists project_env_bin
  func_exists prepare_env
  func_exists require_env
  func_exists expand_dep
  func_exists expand_deps
  func_exists build_params
  func_exists build_error
  test ! -s "$build_errors"
  build_error "Foo"
  test -s "$build_errors"
  TODO "proper testing"
}

