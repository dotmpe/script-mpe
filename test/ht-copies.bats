#!/usr/bin/env bats

base=ht-copies.inc
load init

setup()
{
  init "1" "" "test composure"
}

@test "$base: ht-copies" {

  run ht-copies -- test
  test_ok_nonempty 2 || stdfail
}

@test "$base: ht-directives" {

  run ht-directives -- test
  test_ok_nonempty 9 || stdfail
}

@test "$base: ht-copies-set" {

  rm sh-bats-test || true; touch sh-bats-test
  run ht-copies-set sh-bats-test BIN:other
  { test_ok_nonempty 1 &&
    fnmatch "# Copy: * BIN:other *" "$(head -n 1 sh-bats-test)"
  } || stdfail 1

  rm sh-bats-test && touch sh-bats-test
  run ht-copies-set sh-bats-test BIN:other Sync
  { test_ok_nonempty 1 &&
    fnmatch "# Sync: * BIN:other *" "$(head -n 1 sh-bats-test)"
  } || stdfail 2

  rm sh-bats-test && touch sh-bats-test
  run ht-copies-set sh-bats-test BIN:other Sync-From
  { test_ok_nonempty 1 &&
    fnmatch "# Sync-From: * BIN:other *" "$(head -n 1 sh-bats-test)"
  } || stdfail 3
}

@test "$base: ht-copies-check" {
  TODO
}

@test "$base: ht-copy-directive-parse" {
 
  PD_TAB=test/var/pd-test.tab

  base='<base>' ht-directive-parse "# Via: App/Ver-Id"
  assert_equals \
    "$other_symbol" "App-A" \
    "$other_base" "<base>" \
    "$other_cwd" "/test/app/A" \
    "$directive" "Via"

  base='base' ht-directive-parse "# Via: App/Ver-Id name"
  assert_equals \
    "$other_base" "name" \
    "$other_cwd" "/test/app/A" \
    "$directive" "Via"

  ht-directive-parse "# Copy: App/Ver-Id Pref:other-name"
  assert_equals \
    "$other_base" "other-name" \
    "$other_cwd" "/test/app/A" \
    "$directive" "Copy"

  ht-directive-parse "# Sync: App-B:other-name"
  assert_equals \
    "$other_base" "other-name" \
    "$other_cwd" "/test/app/B" \
    "$directive" "Sync"

  ht-directive-parse "# Sync-With: App:other-name ctx mode-line"
  assert_equals \
    "$other_base" "other-name" \
    "$other_cwd" "/test/app" \
    "$rest" "ctx mode-line" \
    "$directive" "Sync-With"

  ht-directive-parse "# Copy-To: App/Ver-Id Pref:other-name ctx mode-line"
  assert_equals \
    "$other_base" "other-name" \
    "$other_cwd" "/test/symbol-id" \
    "$directive" "Copy-To"

}

@test "$base: ht-copies-sync" {
  TODO
}

@test "$base: ht-copies-sync-from-to" {
  TODO
}
