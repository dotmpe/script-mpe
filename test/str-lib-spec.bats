#!/usr/bin/env bats

base=str.lib
load init


setup()
{
  test_1="foo:/bar_/El Baz.1234.ext"
  test_id="foo:/bar_/El-Baz.1234.ext"

  init 0 &&

  lib_load str match
}


@test "$base: mk*id env pollution" {
  test -z "$c" || fail "c: $c"
  # FIXME: test -z "$s" || fail "s: $s"
  # FIXME: test -z "$upper" || fail "upper: $upper"
}


@test "$base: mkid - with some special web chars, input is output (default)" {
  unset upper

  mkid "$test_id" "" '\.\\\/:_' 
  test "$id" = "$test_id" || stdfail "$id"
  mkid "$test_id" "" '\.\\\/:_' 
  test "$id" = "$test_id" || stdfail "$id"
}

@test "$base: mkid - with no special chars, all are collapsed to '-' " {
  unset upper

  mkid "$test_1" "" ""
  test "$id" = "foo-bar-El-Baz-1234-ext" || fail "$id"
}

@test "$base: mkid - default, allows A-Za-z0-9:/_-. " {
  unset upper

  mkid "$test_1"
  test "$id" = "foo:/bar_/El-Baz.1234.ext" || stdfail "$id"
}

@test "$base: mkid - lower, allows A-Za-z0-9:/_-. " {

  upper=0 mkid "$test_1" ""
  test "$id" = "foo:/bar_/el-baz.1234.ext" || stdfail "$id"
}

@test "$base: mksid - alphanum and hyphen" {
  unset upper

  mksid "$test_1"
  test "$id" = "foo-bar_-El-Baz-1234-ext" || stdfail "A. $id"

  upper=0 mksid "$test_1"
  test "$id" = "foo-bar_-el-baz-1234-ext" || stdfail "B. $id"
}

@test "$base: mksid - can make ID from path" {
  unset s c upper

  mksid "$test_1"
  test "$id" = "foo-bar_-El-Baz-1234-ext" || stdfail "A. $id"

  mksid "$test_1" "" "."
  test "$id" = "foo-bar-El-Baz.1234.ext" || stdfail "B. $id"

  mksid "$test_1" "" "_."
  test "$id" = "foo-bar_-El-Baz.1234.ext" || stdfail "C. $id"
}


@test "$base: mksid - can make SId from VId" {
  unset s c upper

  mksid "$test_1" "-" "-"
  test "$id" = "foo-bar-El-Baz-1234-ext" || stdfail "A. $id"
}


@test "$base: mkvid - can make ID from path" {
  unset s c upper

  mkvid "/var/lib"
  test "$vid" = "_var_lib"
  mkvid "/var/lib/"
  test "$vid" = "_var_lib_"
}

@test "$base: mkvid - cleans up ID from path" {
  unset s c upper

  mkvid "/var//lib//"
  test "$vid" = "_var_lib_"
  mkvid "/var//lib"
  test "$vid" = "_var_lib"
}


@test "$base: str-replace" {
  test "$(str_replace "foo/bar" "o/b" "o-b")" = "foo-bar"
}


@test "$base: resolve_prefix_element" {
  element=$(resolve_prefix_element 1 123:456)
  test "${element}" = "123" || fail "${element}"
  element=$(resolve_prefix_element 2 123:456)
  test "${element}" = "456" || fail "${element}"
  element=$(resolve_prefix_element 1 :123:456)
  test "${element}" = "" || fail "${element}"
  element=$(resolve_prefix_element 3 123:456:)
  test "${element}" = "" || fail "${element}"
  element=$(resolve_prefix_element 4 123:456:abcd-dfs:A:)
  test "${element}" = "A" || fail "${element}"
}


@test "$base: expr-substr - Should fail if not initialized" {

  expr_old=$expr
  
  expr=illegal-value 
  run expr_substr "FOO" 1 3
  test ${status} -ne 0 || fail "Should not pass illegal setting"

  str_lib_load
  run expr_substr "FOO" 1 3
  test ${status} -eq 0 || fail "Should pass after str-load"
}


@test "$base: expr-substr: should slice simple string " {

  test -n "$expr" || fail "expr failed to init"
  test "$(expr_substr "testFOObar" 1 4)" = "test"
  test "$(expr_substr "testFOObar" 5 3)" = "FOO"
  test "$(expr_substr "testFOObar" 8 3)" = "bar"
  test "$(expr_substr "testFOObar" 1 10)" = "testFOObar"
}


@test "$base: expr-substr: should slice with leading hyphen" {

  test -n "$expr" || fail "expr failed to init"
  test "$(expr_substr "-E" 1 2)" = "-E"
  test "$(expr_substr "---" 1 1)" = "-"
  test "$(expr_substr "---" 1 2)" = "--"
  test "$(expr_substr "---" 1 3)" = "---"
}


@test "$base: lines-quoted" {

  run lines_quoted test/var/urls1.list
  { test_ok_nonempty 8 && test_lines '""' '"# vim:ft=todo.txt"'
  } || stdfail
}


@test "$base: lines-to-args" {

  run lines_to_args test/var/urls1.list
  { test_ok_nonempty 1 && test_lines "\"https:*" "*\"# vim:ft=todo.txt\"*"
  } || stdfail
}


# Id: script-mpe/0.0.4-dev test/str-lib-spec.bats
