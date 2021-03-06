#!/usr/bin/env bats

#export verbosity=6
load helper

test -z "$PREFIX" && scriptpath=. || scriptpath=$PREFIX

lib=$scriptpath/str.lib

check_env()
{
  fnames="$(grep '^[a-zA-Z0-9_]*()' $lib.sh | tr -s '()\n' ' ')"
  for fname in $fnames
  do
    type $fname >/dev/null 2>/dev/null \
       && {
  
        set | grep '\<'$fname'=' \
          >/dev/null 2>/dev/null \
          && continue
  
        echo "Unexpected '$fname' function"
        fail "Unexpected '$fname' function"
      }
  done
}

setup()
{
  test_1="foo:/bar_/El Baz.1234.ext"
  test_id="foo:/bar_/El-Baz.1234.ext"

  #check_env
  . $scriptpath/util.sh load-ext &&
  lib_load sys os std str match &&
  str_lib_load
}


@test "$lib mk*id env pollution" {
  test -z "$c" || fail "c: $c"
  # FIXME: test -z "$s" || fail "s: $s"
  # FIXME: test -z "$upper" || fail "upper: $upper"
}


@test "$lib mkid - with some special web chars, input is output (default)" {
  unset upper

  mkid "$test_id" "" '\.\\\/:_' 
  test "$id" = "$test_id" || stdfail "$id"
  mkid "$test_id" "" '\.\\\/:_' 
  test "$id" = "$test_id" || stdfail "$id"
}

@test "$lib mkid - with no special chars, all are collapsed to '-' " {
  unset upper

  mkid "$test_1" "" ""
  test "$id" = "foo-bar-El-Baz-1234-ext" || fail "$id"
}

@test "$lib mkid - default, allows A-Za-z0-9:/_-. " {
  unset upper

  mkid "$test_1"
  test "$id" = "foo:/bar_/El-Baz.1234.ext" || stdfail "$id"
}

@test "$lib mkid - lower, allows A-Za-z0-9:/_-. " {

  upper=0 mkid "$test_1" ""
  test "$id" = "foo:/bar_/el-baz.1234.ext" || stdfail "$id"
}

@test "$lib mksid - alphanum and hyphen" {
  unset upper

  mksid "$test_1"
  test "$id" = "foo-bar_-El-Baz-1234-ext" || stdfail "A. $id"

  upper=0 mksid "$test_1"
  test "$id" = "foo-bar_-el-baz-1234-ext" || stdfail "B. $id"
}

@test "$lib mksid - can make ID from path" {
  unset s c upper

  mksid "$test_1"
  test "$id" = "foo-bar_-El-Baz-1234-ext" || stdfail "A. $id"

  mksid "$test_1" "" "."
  test "$id" = "foo-bar-El-Baz.1234.ext" || stdfail "B. $id"

  mksid "$test_1" "" "_."
  test "$id" = "foo-bar_-El-Baz.1234.ext" || stdfail "C. $id"
}


@test "$lib mksid - can make SId from VId" {
  unset s c upper

  mksid "$test_1" "-" "-"
  test "$id" = "foo-bar-El-Baz-1234-ext" || stdfail "A. $id"
}


@test "$lib mkvid - can make ID from path" {
  unset s c upper

  mkvid "/var/lib"
  test "$vid" = "_var_lib"
  mkvid "/var/lib/"
  test "$vid" = "_var_lib_"
}

@test "$lib mkvid - cleans up ID from path" {
  unset s c upper

  mkvid "/var//lib//"
  test "$vid" = "_var_lib_"
  mkvid "/var//lib"
  test "$vid" = "_var_lib"
}


@test "$lib str_replace" {
  test "$(str_replace "foo/bar" "o/b" "o-b")" = "foo-bar"
}


@test "$lib resolve_prefix_element" {
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


@test "$lib expr-substr - Should fail if not initialized" {

  expr_old=$expr
  
  expr=illegal-value 
  run expr_substr "FOO" 1 3
  test ${status} -ne 0 || fail "Should not pass illegal setting"

  str_lib_load
  run expr_substr "FOO" 1 3
  test ${status} -eq 0 || fail "Should pass after str-load"
}


@test "$lib expr_substr: should slice simple string " {

  func_exists expr_substr
  test -n "$expr" || fail "expr failed to init"
  test "$(expr_substr "testFOObar" 1 4)" = "test"
  test "$(expr_substr "testFOObar" 5 3)" = "FOO"
  test "$(expr_substr "testFOObar" 8 3)" = "bar"
  test "$(expr_substr "testFOObar" 1 10)" = "testFOObar"
}


@test "$lib expr_substr: should slice with leading hyphen" {

  func_exists expr_substr
  test -n "$expr" || fail "expr failed to init"
  test "$(expr_substr "-E" 1 2)" = "-E"
  test "$(expr_substr "---" 1 1)" = "-"
  test "$(expr_substr "---" 1 2)" = "--"
  test "$(expr_substr "---" 1 3)" = "---"
}

# Id: script-mpe/0.0.4-dev test/str-lib-spec.bats
