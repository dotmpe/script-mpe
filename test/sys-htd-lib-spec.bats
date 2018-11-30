#!/usr/bin/env bats

base=sys-htd.lib
load init

setup()
{
  init && lib_load sys htd-sys
}

# util / Var Isset

@test "$base: var-isset depends on SCR-SYS-SH " {

  func_exists fnmatch

  lib_load sys
  diag "Shell: $SHELL, Scr-Sys-Sh: $SCR_SYS_SH"
  {
    fnmatch "bash-sh" "$SCR_SYS_SH" || fnmatch "sh" "$SCR_SYS_SH"
  } && {
    type set
  } || {
    true
  }
}

@test "$base: var-isset detects vars correctly even if empty" {

  func_exists var_isset

  lib_load sys
  ( 
    env | grep -v '^[A-Z0-9_]*=' | grep '\<foo_bar='
  ) && fail "unexpected" || true
  var_isset foo_bar && fail "1. Unexpected foo_bar set ($?)" || true

  run var_isset foo_bar
  test $status -eq 1 || fail "2. Unexpected foo_bar set ($status)"

  # XXX: Bats with non-bash test subshell?
  test -n "$SHELL" -a "$(basename $SHELL)" = "sh" || skip

  foo_bar=
  run var_isset foo_bar
  test $status -eq 0 || fail "3. Expected foo_bar set ($status)"
  unset foo_bar
  run var_isset foo_bar
  test $status -eq 1 || fail "4. Unexpected foo_bar set ($status)"
}

@test "$base: var-isset detects vars correctly even if empty (sh wrapper)" {

  lib_load sys
  ./test/util-lib-spec.sh var-isset foo_bar && fail "1. Unexpected foo_bar set ($?)" || echo

  run ./test/util-lib-spec.sh var-isset foo_bar
  test $status -eq 1 || 
    fail "2. Unexpected foo_bar set ($status; pwd $(pwd); out ${lines[*]})"

  run sh -c "foo_bar= ./test/util-lib-spec.sh var-isset foo_bar"
  test $status -eq 0 || fail "3. Expected foo_bar set ($status; out ${lines[*]})"
}


@test "$base: var-isset detects vars correctly even if empty (bash wrapper)" {

  lib_load sys
  local scriptpath="$(pwd)"
  ./test/util-lib-spec.bash var-isset foo_bar && fail "1. Unexpected foo_bar set ($?)"

  run ./test/util-lib-spec.bash var-isset foo_bar
  test $status -eq 1 ||
    fail "2. Unexpected foo_bar set ($status; pwd $(pwd); out ${lines[*]})"
  run bash -c "foo_bar= ./test/util-lib-spec.bash var-isset foo_bar"
  test $status -eq 0 || fail "3. Expected foo_bar set ($status; out ${lines[*]})"
}


@test "$base: var-isset detects vars correctly even if empty, exported" {

  lib_load sys
  var_isset foo_bar && fail "1. Unexpected foo_bar set ($?)"
  run var_isset foo_bar
  test $status -eq 1 || fail "2. Unexpected foo_bar set ($status)"
  export foo_bar=
  run var_isset foo_bar
  test $status -eq 0 || fail "3. Expected foo_bar set ($status)"
  unset foo_bar
  run var_isset foo_bar
  test $status -eq 1 || fail "4. Unexpected foo_bar set ($status)"
  export foo_bar=
  run var_isset foo_bar
  test $status -eq 0 || fail "5. Expected foo_bar set ($status)"
  unset foo_bar
  run var_isset foo_bar
  test $status -eq 1 || fail "6. Unexpected foo_bar set ($status)"
}

@test "$base: var-isset detects vars correctly even if empty, local declaration" {

  lib_load sys
  # XXX: Bats with non-bash test subshell?
  diag "Sh: $SHELL"
  test -n "$SHELL" -a "$(basename $SHELL)" = "sh" || skip

  local foo_bar_baz=
  run var_isset foo_bar_baz 
  test $status -eq 0 || fail "Expected foo_bar_baz set ($status)"

  unset foo_bar_baz
  run var_isset foo_bar_baz
  test $status -eq 1 || fail "Unexpected foo_bar_baz ($status)"

  unset foo_bar
}
