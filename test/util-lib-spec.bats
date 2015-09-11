#!/usr/bin/env bats

load helper
load main.inc

init_lib
source $lib/util.sh
source $lib/main.sh


# XXX: clean me up to a test-helper func
test_inc="$lib/util.sh $lib/main.sh $lib/test/helper.bash $lib/test/main.inc.bash"
test_inc_bash="source $(echo $test_inc | sed 's/\ / \&\& source /g')"
test_inc_sh=". $(echo $test_inc | sed 's/\ / \&\& . /g')"


# util / Try-Exec

@test "$lib test run test functions to verify" {

  run mytest_function
  test $status -eq 0
  test "${lines[0]}" = "mytest"

  run mytest_load
  test $status -eq 0
  test "${lines[0]}" = "mytest_load"
}

@test "$lib test run non-existing function to verify" {

  run sh -c 'no_such_function'
  test $status -eq 127

  case "$(uname)" in
    Darwin )
      test "sh: no_such_function: command not found" = "${lines[0]}"
      ;;
    Linux )
      test "${lines[0]}" = "sh: 1: no_such_function: not found"
      ;;
  esac

  run bash -c 'no_such_function'
  test $status -eq 127
  test "${lines[0]}" = "bash: no_such_function: command not found"
}

@test "$lib try_exec_func on existing function" {

  run try_exec_func mytest_function
  test $status -eq 0
  test "${lines[0]}" = "mytest"
}

@test "$lib try_exec_func on non-existing function" {

  run try_exec_func no_such_function
  test $status -eq 1
}

@test "$lib try_exec_func (bash) on existing function" {

  run bash -c 'source '$lib'/util.sh && \
    source '$lib'/test/main.inc.bash && try_exec_func mytest_function'
  test "${lines[0]}" = "mytest"
  test $status -eq 0
}

@test "$lib try_exec_func (bash) on non-existing function" {

  run bash -c 'source '$lib'/util.sh && try_exec_func no_such_function'
  test "" = "${lines[*]}"
  test $status -eq 1

  run bash -c 'type no_such_function'
  test "bash: line 0: type: no_such_function: not found" = "${lines[0]}"
  test $status -eq 1
}

@test "$lib try_exec_func (sh) on existing function" {

  run sh -c '. '$lib'/util.sh && \
    . '$lib'/test/main.inc.bash && try_exec_func mytest_function'
  test "${lines[0]}" = "mytest"
  test $status -eq 0
}

@test "$lib try_exec_func (sh) on non-existing function" {

  run sh -c '. '$lib'/util.sh && try_exec_func no_such_function'
  test "" = "${lines[*]}"

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

@test "$lib/util var-isset detects vars correctly if empty, wether local or not" {

    foo_bar=
    run var_isset foo_bar || test

    local foo_bar_baz=
    run var_isset foo_bar_baz || test

    local r=0
    unset foo_bar_baz
    run var_isset foo_bar_baz && test || { r=$?; noop; }
    test $r -eq 1
    # .. && test || .. should be equiv. but.. sanity checking once in a while..
    #test $status -eq 1

    unset foo_bar
    export foo_bar=
    run var_isset foo_bar || test

    unset foo_bar
    run var_isset foo_bar && test || noop
}


@test "$lib noop" {

  func_exists noop
  run noop
  test $status -eq 0
  test -z "${lines[*]}"
}


@test "$lib short" {

  func_exists short
  run short
  test $status -eq 0
  test "${lines[*]}" = "~/bin"
}


@test "$lib file_insert_where_before" {
  skip "TODO"
}

@test "$lib file_insert_at" {
  skip "TODO"
}

@test "$lib file_where_before" {

  func_exists file_where_before
  run file_where_before
  test $status -eq 1
  fnmatch "*where-grep required*" "${lines[*]}"

  run file_where_before where
  test $status -eq 1
  fnmatch "*file-path required*" "${lines[*]}"
}


@test "$lib get_uuid" {

  func_exists get_uuid
  run get_uuid
  test $status -eq 0
  test -n "${lines[*]}"
}


# vim:ft=sh:
