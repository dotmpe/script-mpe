#!/usr/bin/env bats

load init
base=sys.lib

setup()
{
  init &&
  main_inc=$SHT_PWD/var/sh-src-main-mytest-funcs.sh &&
  . $main_inc &&
  export SCR_SYS_SH= &&
  sys_lib_load
}


# util / Try-Exec

@test "$base: try_exec_func on existing function" {

  run try_exec_func mytest_function
  { test $status -eq 0 &&
    fnmatch "mytest" "${lines[*]}"
  } || stdfail
}

@test "$base: try_exec_func on non-existing function" {

  run try_exec_func no_such_function
  test $status -eq 1
}

@test "$base: try_exec_func (bash) on existing function" {

  run bash -c 'scriptpath='$lib' && __load_mode=boot source '$lib'/util.sh && \
    source '$main_inc' && try_exec_func mytest_function'
  diag "Output: ${lines[0]}"
  {
    test $status -eq 0 &&
    fnmatch "mytest" "${lines[*]}"
  } || stdfail 3.
}

@test "$base: try_exec_func (bash) on non-existing function" {

  export verbosity=6
  run bash -c 'scriptpath='$lib' && __load_mode=boot source '$lib'/util.sh && try_exec_func no_such_function'
  {
    test "" = "${lines[*]}" &&
    test $status -eq 1
  } || stdfail 4.1.1

  export verbosity=7
  run bash -c 'scriptpath='$lib' && __load_mode=boot source '$lib'/util.sh && try_exec_func no_such_function'
  {
    fnmatch "*try-exec-func 'no_such_function'*" "${lines[*]}" &&
    test $status -eq 1
  } || stdfail 4.1.2

  export verbosity=6
  run bash -c 'type no_such_function'
  {
    test "bash: line 0: type: no_such_function: not found" = "${lines[0]}" &&
    test $status -eq 1
  } || stdfail 4.2
}

@test "$base: try_exec_func (sh) on existing function" {

  export verbosity=5
  run sh -c 'TERM=dumb && scriptpath='$lib' && __load_mode=boot . '$lib'/util.sh && \
    . '$main_inc' && try_exec_func mytest_function'
  {
    test -n "${lines[*]}" &&
    test "${lines[0]}" = "mytest" &&
    test $status -eq 0
  } || stdfail
}

@test "$base: try_exec_func (sh) on non-existing function" {

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

@test "$base: var-isset depends on SCR-SYS-SH " {

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

  ./test/util-lib-spec.sh var-isset foo_bar && fail "1. Unexpected foo_bar set ($?)" || echo

  run ./test/util-lib-spec.sh var-isset foo_bar
  test $status -eq 1 || 
    fail "2. Unexpected foo_bar set ($status; pwd $(pwd); out ${lines[*]})"

  run sh -c "foo_bar= ./test/util-lib-spec.sh var-isset foo_bar"
  test $status -eq 0 || fail "3. Expected foo_bar set ($status; out ${lines[*]})"
}


@test "$base: var-isset detects vars correctly even if empty (bash wrapper)" {

  local scriptpath="$(pwd)"
  ./test/util-lib-spec.bash var-isset foo_bar && fail "1. Unexpected foo_bar set ($?)"

  run ./test/util-lib-spec.bash var-isset foo_bar
  test $status -eq 1 ||
    fail "2. Unexpected foo_bar set ($status; pwd $(pwd); out ${lines[*]})"
  run bash -c "foo_bar= ./test/util-lib-spec.bash var-isset foo_bar"
  test $status -eq 0 || fail "3. Expected foo_bar set ($status; out ${lines[*]})"
}


@test "$base: var-isset detects vars correctly even if empty, exported" {
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


@test "${base}: capture CMD captures subshell return status to var while redirecting output" {

  run capture true '' '' '' "foo"
  test_ok_empty || stdfail 1.1.
  run capture false '' '' '' "bar" "baz"
  test_ok_empty || stdfail 1.2.

  tmpf ; out_file=$tmpf ; __test__() {
     ret_var=
     capture ls '' 'out_file' ''  -la
     echo "ret_var=$ret_var"
     echo "out_file=$out_file"
  }
  run __test__
  { test_ok_nonempty 2 && test_lines "ret_var=0" "out_file=$tmpf" &&
	grep '\<ReadMe\.rst\>' "$tmpf" && 
    rm "$out_file" &&  unset tmpf out_file
  } || stdfail 2.
}


@test "${base}: capture CMD handles command pipeline input as well" {

  tmpf ; input=$tmpf
  tmpf ; out_file=$tmpf
  __test__() {
     ret_var=
     echo some input >"$input"
     capture cat 'ret_var' 'out_file' "$input"
     echo "ret_var=$ret_var"
     echo "out_file=$out_file"
  }
  run __test__
  { test_ok_nonempty 2 && test_lines "ret_var=0" "out_file=$tmpf" &&
	grep '^some input$' "$tmpf" && rm "$input" "$out_file" &&
     unset input out_file tmpf
  } || stdfail 'A'
}


@test "${base}: capture-var or eval cmd-string" {

  func_exists capture_var

  my_cmd()
  {
    echo "${1}2ab"
  }

  # Test all args
  pref= set_always= capture_var my_cmd ret out 1
  { test "$out" = "12ab" && test "$ret" = "0" && unset out ret
  } || stdfail "1: out-var: $out, ret-var: $ret"

  # Test default out
  pref= set_always= capture_var my_cmd ret "" 2
  { test "$my_cmd" = "22ab" && test "$ret" = "0"
    # && unset my_cmd ret
  } || stdfail "2: out-var: $my_cmd, ret-var: $ret"

  # Test eval
  pref=eval set_always= capture_var 'my_cmd "$@" | cat -' ret out 3
  { test "$out" = "32ab" && test "$ret" = "0" && unset out ret
  } || stdfail "3: out-var: $out, ret-var: $ret"
}


# Id: script-mpe/0.0.4-dev test/sys-lib-spec.bats
