#!/usr/bin/env bats

VND_SRC_PREFIX=/src/local
load init
base=statusdir.sh
init 0
. $U_S/tools/sh/init.sh || return
lib_load str date statusdir || return
load assert || return

setup()
{
  base=statusdir.sh
  assert test -n "$STATUSDIR_ROOT"
  assert test -d "$STATUSDIR_ROOT"index
}

@test "statusdir.sh index{,-file,-notify} -- ls -la: blank id, default age and expiry" {

  local expected_file=${STATUSDIR_ROOT}index/_ls_la
  test ! -e $expected_file || rm $expected_file

  run $base index-file -- ls -la
  assert_success
  assert test ! -e "${lines[2]}" -a 5 -eq ${#lines[@]}
  assert_equal "$expected_file" "${lines[2]}"

  # No index argument whatsoever works fine;
  run $base index -- ls -la
  assert_success
  assert test 100 -lt ${#lines[@]}
  # uses generated ID, no other presets.
  test -e "$expected_file"
  # Default, global expiry, no max-age means value is not updated again.
  # But utime is, so default expiration still shifts each time.
  lib_load os
  mtime=$(filemtime $expected_file)

  # index-notify handles output differently
  #run $base index-notify -- ls -la
  #assert_success
  # XXX: assert test ${#lines[@]} -eq 0 stdout-only
  #assert test 100 -gt ${#lines[@]}
}

@test "statusdir.sh index{,-file,-notify} cache-1-test -- ls -la: provide ID" {

  # No max-age means default max-age is recorded
  #run $base index cache-1-test -- ls -la
  #run $base index cache-1-test 300 -- ls -la
  #run $base index cache-1-test 300 3600 -- ls -la

  run $base index cache-1-test -- ls -la
  assert_success
}

@test "statusdir.sh index 600 cache-2-test -- ls -la: provide expiry-age" {

  run $base index 600 cache-1-test -- ls -la
  assert_success
}

@test "statusdir.sh index 600 1200 cache-3-test -- ls -la: provide expiry- and expiration-age" {

  run $base index 600 3600 cache-1-test -- ls -la
  assert_success
}
