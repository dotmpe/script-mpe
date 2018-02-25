#!/usr/bin/env bats

load init
base=sys.lib

init

load main.inc


# util / Try-Exec

@test "${base} - try_exec_func on existing function" {

  run try_exec_func mytest_function
  { test $status -eq 0 &&
    fnmatch "mytest" "${lines[*]}"
  } || stdfail
}

@test "${base} - try_exec_func on non-existing function" {

  run try_exec_func no_such_function
  test $status -eq 1
}

@test "${base} - try_exec_func (bash) on existing function" {

  run bash -c 'scriptpath='$lib' && __load_mode=boot source '$lib'/util.sh && \
    source '$lib'/test/main.inc.bash && try_exec_func mytest_function'
  diag "Output: ${lines[0]}"
  {
    test $status -eq 0 &&
    fnmatch "mytest" "${lines[*]}"
  } || stdfail
}

@test "${base} - try_exec_func (bash) on non-existing function" {

  export verbosity=6
  run bash -c 'scriptpath='$lib' && __load_mode=boot source '$lib'/util.sh && try_exec_func no_such_function'
  {
    test "" = "${lines[*]}" &&
    test $status -eq 1
  } || stdfail 1.1

  export verbosity=7
  run bash -c 'scriptpath='$lib' && __load_mode=boot source '$lib'/util.sh && try_exec_func no_such_function'
  {
    fnmatch "*try-exec-func 'no_such_function'*" "${lines[*]}" &&
    test $status -eq 1
  } || stdfail 1.2

  export verbosity=6
  run bash -c 'type no_such_function'
  {
    test "bash: line 0: type: no_such_function: not found" = "${lines[0]}" &&
    test $status -eq 1
  } || stdfail 2
}

@test "${base} - try_exec_func (sh) on existing function" {

  export verbosity=5
  run sh -c 'TERM=dumb && scriptpath='$lib' && __load_mode=boot . '$lib'/util.sh && \
    . '$lib'/test/main.inc.bash && try_exec_func mytest_function'
  {
    test -n "${lines[*]}" &&
    test "${lines[0]}" = "mytest" &&
    test $status -eq 0
  } || stdfail
}

@test "${base} - try_exec_func (sh) on non-existing function" {

  export verbosity=5

  run sh -c 'TERM=dumb && scriptpath='$lib' && __load_mode=boot . '$lib'/util.sh && try_exec_func no_such_function'
  test "" = "${lines[*]}" || stdfail 1

  case "$(uname)" in
    Darwin )
      test $status -eq 1
      ;;
    Linux )
      test $status -eq 127
      ;;
  esac

  run sh -c 'type no_such_function'
  case "$(uname)" in
    Darwin )
      test "sh: line 0: type: no_such_function: not found" = "${lines[0]}"
      test $status -eq 1
      ;;
    Linux )
      test "no_such_function: not found" = "${lines[0]}"
      test $status -eq 127
      ;;
  esac
}


# util / Var Isset

@test "${base} - var-isset detects vars correctly even if empty" {

  ( 
    env | grep -v '^[A-Z0-9_]*=' | grep '\<foo_bar='
  ) && fail "unexpected" || echo ""
  var_isset foo_bar && fail "1. Unexpected foo_bar set ($?)"

  run var_isset foo_bar
  test $status -eq 1 || fail "2. Unexpected foo_bar set ($status)"

  # FIXME: must bats always be running as Bash
  test "$(basename $SHELL)" = "sh" || skip "Sh: $SHELL"

  foo_bar=
  run var_isset foo_bar
  test $status -eq 0 || fail "3. Expected foo_bar set ($status)"
  unset foo_bar
  run var_isset foo_bar
  test $status -eq 1 || fail "4. Unexpected foo_bar set ($status)"
}

@test "${base} - var-isset detects vars correctly even if empty (sh wrapper)" {

  ./test/util-lib-spec.sh var-isset foo_bar && fail "1. Unexpected foo_bar set ($?)" || echo

  run ./test/util-lib-spec.sh var-isset foo_bar
  test $status -eq 1 || 
    fail "2. Unexpected foo_bar set ($status; pwd $(pwd); out ${lines[*]})"

  run sh -c "foo_bar= ./test/util-lib-spec.sh var-isset foo_bar"
  test $status -eq 0 || fail "3. Expected foo_bar set ($status; out ${lines[*]})"
}


@test "${base} - var-isset detects vars correctly even if empty (bash wrapper)" {

  local scriptpath="$(pwd)"
  ./test/util-lib-spec.bash var-isset foo_bar && fail "1. Unexpected foo_bar set ($?)"

  run ./test/util-lib-spec.bash var-isset foo_bar
  test $status -eq 1 ||
    fail "2. Unexpected foo_bar set ($status; pwd $(pwd); out ${lines[*]})"
  run bash -c "foo_bar= ./test/util-lib-spec.bash var-isset foo_bar"
  test $status -eq 0 || fail "3. Expected foo_bar set ($status; out ${lines[*]})"
}


@test "${base} - var-isset detects vars correctly even if empty, exported" {
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

@test "${base} - var-isset detects vars correctly even if empty, local declaration" {

  # FIXME: must bats always be running as Bash
  test "$(basename $SHELL)" = "sh" || skip "Sh: $SHELL"

  local foo_bar_baz=
  run var_isset foo_bar_baz 
  test $status -eq 0 || fail "Expected foo_bar_baz set ($status)"

  unset foo_bar_baz
  run var_isset foo_bar_baz
  test $status -eq 1 || fail "Unexpected foo_bar_baz ($status)"

  unset foo_bar
}


@test "${base} - noop" {

  func_exists noop
  run noop
  test $status -eq 0
  test -z "${lines[*]}"
}


# FIXME: this is far to slow
@test "${base} - short" {
  check_skipped_envs travis || skip "Nothing much to test anyway"

  func_exists short
  run short
  test $status -eq 0 || fail "${lines[*]}"

  fnmatch "$HOME*" "$lib" && {
    fnmatch "~/*" "${lines[*]}"
  } || {
    test "$lib" = "${lines[*]}"
  }
}


# Id: script-mpe/0.0.4-dev test/sys-lib-spec.bats
