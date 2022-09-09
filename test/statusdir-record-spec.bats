#!/usr/bin/env bats

VND_SRC_PREFIX=/src/local
load init
base=statusdir.sh
init 1 0
. $U_S/tools/sh/init.sh || return
lib_load str date statusdir || return
load assert || return

setup()
{
  assert test -n "$STATUSDIR_ROOT"
  assert test -d "$STATUSDIR_ROOT"cache
}

@test "statusdir.sh cache{,-file,-notify} -- ls -la: blank id, default age and expiry" {

  local expected_file=${STATUSDIR_ROOT}cache/_ls_la
  test ! -e $expected_file || rm $expected_file

  run $base record -- ls -la
  assert_success
  assert test 1 -eq ${#lines[@]}
  assert_equal "$expected_file" "${lines[0]}"
  assert test ! -e "${lines[0]}"

  # No cache argument whatsoever works fine;
  choice_contents=1
  run $base record -- ls -la
  assert_success
  assert test 100 -lt ${#lines[@]}
  assert test 1000 -gt ${#lines[@]}
  # uses generated ID, no other presets.
  test -e "$expected_file"
  # Default, global expiry, no max-age means value is not updated again.
  # But utime is, so default expiration still shifts each time.
  lib_load os
  mtime=$(filemtime $expected_file)

  # cache-notify handles output differently
  #run $base cache-notify -- ls -la
  #assert_success
  # XXX: assert test ${#lines[@]} -eq 0 stdout-only
  #assert test 100 -gt ${#lines[@]}
}

@test "statusdir.sh cache{,-file,-notify} cache-1-test -- ls -la: provide ID" {

  # No max-age means default max-age is recorded
  #run $base cache cache-1-test -- ls -la
  #run $base cache cache-1-test 300 -- ls -la
  #run $base cache cache-1-test 300 3600 -- ls -la

  run $base cache cache-1-test -- ls -la
  assert_success
}

@test "statusdir.sh cache 600 cache-2-test -- ls -la: provide expiry-age" {

  run $base cache 600 cache-1-test -- ls -la
  assert_success
}

@test "statusdir.sh cache 600 1200 cache-3-test -- ls -la: provide expiry- and expiration-age" {

  run $base cache 600 3600 cache-1-test -- ls -la
  assert_success
}
