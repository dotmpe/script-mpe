#!/usr/bin/env bats

base=main
load helper
load main.inc

init
source $lib/util.sh
source $lib/main.lib.sh

# XXX: clean me up to a test-helper func
test_inc="$lib/util.sh $lib/main.lib.sh $lib/test/helper.bash $lib/test/main.inc.bash"
test_inc_bash="source $(echo $test_inc | sed 's/\ / \&\& source /g')"
test_inc_sh=". $(echo $test_inc | sed 's/\ / \&\& . /g')"



# util / Try-Exec

@test "$lib test run test functions to verify" "" "" {

  run mytest_function
  test $status -eq 0
  test "${lines[0]}" = "mytest"

  run mytest_usage
  test $status -eq 0
  test "${lines[0]}" = "mytest_usage"
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

  run bash -c 'scriptdir='$lib' && source '$lib'/util.sh && \
    source '$lib'/test/main.inc.bash && try_exec_func mytest_function'
  diag "Output: ${lines[0]}"
  test "${lines[0]}" = "mytest"
  test $status -eq 0
}

@test "$lib try_exec_func (bash) on non-existing function" {

  run bash -c 'scriptdir='$lib' && source '$lib'/util.sh && try_exec_func no_such_function'
  test "" = "${lines[*]}"
  test $status -eq 1

  run bash -c 'type no_such_function'
  test "bash: line 0: type: no_such_function: not found" = "${lines[0]}"
  test $status -eq 1
}

@test "$lib try_exec_func (sh) on existing function" {

  run sh -c 'TERM=dumb && scriptdir='$lib' && . '$lib'/util.sh && \
    . '$lib'/test/main.inc.bash && try_exec_func mytest_function'
  test -n "${lines[*]}" || diag "${lines[*]}"
  test "${lines[0]}" = "mytest"
  test $status -eq 0
}

@test "$lib try_exec_func (sh) on non-existing function" {

  run sh -c 'TERM=dumb && scriptdir='$lib' && . '$lib'/util.sh && try_exec_func no_such_function'
  test -n "${lines[*]}" || diag "${lines[*]}"
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


# FIXME: this is far to slow
@test "$lib short" {
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


@test "$lib file_insert_where_before" {
  TODO
}

@test "$lib file_insert_at" {
  TODO
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

@test "expr-substr - Should fail if not initialized" {

  test -z "$expr" || {
    diag "expr=$expr"
    diag "$(set | grep expr)"
    fail "Should not be initialized"
  }

  expr=illegal-value 
  run expr_substr "FOO" 1 3
  test ${status} -ne 0 || fail "Should not pass illegal setting"

  . $lib/main.init.sh
  run expr_substr "FOO" 1 3
  test ${status} -eq 0 || fail "Should pass after init"
}

@test "$lib expr_substr: should slice simple string " {

  func_exists expr_substr
  . $lib/main.init.sh
  test -n "$expr" || fail "expr failed to init"
  test "$(expr_substr "testFOObar" 1 4)" = "test"
  test "$(expr_substr "testFOObar" 5 3)" = "FOO"
  test "$(expr_substr "testFOObar" 8 3)" = "bar"
  test "$(expr_substr "testFOObar" 1 10)" = "testFOObar"
}


@test "$lib expr_substr: should slice with leading hyphen" {

  func_exists expr_substr
  . $lib/main.init.sh
  test -n "$expr" || fail "expr failed to init"
  test "$(expr_substr "-E" 1 2)" = "-E"
  test "$(expr_substr "---" 1 1)" = "-"
  test "$(expr_substr "---" 1 2)" = "--"
  test "$(expr_substr "---" 1 3)" = "---"
}


@test "$lib truncate_trailing_lines: " {

  echo
  tmpd
  out=$tmpd/truncate_trailing_lines
  printf "1\n2\n3\n4" >$out
  test -s "$out"
  ll="$(truncate_trailing_lines $out 1)"
  test -n "$ll"
  test "$ll" = "4"
}

@test "$lib line_count: " {

  tmpd
  out=$tmpd/line_count

  printf "1\n2\n3\n4" >$out
  test "$(wc -l $out|awk '{print $1}')" = "3"
  test "$(line_count $out)" = "4"

  printf "1\n2\n3\n4\n" >$out
  test "$(wc -l $out|awk '{print $1}')" = "4"
  test "$(line_count $out)" = "4"

  #uname=$(uname -s)
  #printf "1\r" >$out
  #test -n "$(line_count $out)"
}


@test "$lib header-comment test/var/nix_comments.txt prints file header comment, exports env" {
  local testf=test/var/nix_comments.txt r=
  header_comment $testf > $testf.header || r=$?
  md5ck="$(echo $(md5sum $testf.header | awk '{print $1}'))"
  rm $testf.header
  test -z "$r" 
  test "$md5ck" = "b37a5e1dd5f33d5ea937de72587052c7"
  test $line_number -eq 4
}

@test "$lib backup-header-comment test/var/nix_comments.txt writes comment-header file" {
  local testf=test/var/nix_comments.txt
  run backup_header_comment $testf
  test $status -eq 0
  test -z "${lines[*]}"
  test -s $testf.header
  test "$(echo $(md5sum $testf.header | awk '{print $1}'))" \
    = "b37a5e1dd5f33d5ea937de72587052c7"
}


