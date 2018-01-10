#!/usr/bin/env bats

base=edl
load helper
init


@test "$lib resolve_prefix_element" "" "" {

  ref="prefix:file:123:<4>:<5>:<6>:<7>:<8>:<9>:<10>: Comment: Foo "
  
  run resolve_prefix_element 1 "$ref"
  test $status -eq 0
  test "${lines[0]}" = "prefix"
  
  run resolve_prefix_element 2 "$ref"
  test "${lines[0]}" = "file"
  
  run resolve_prefix_element 3 "$ref"
  test "${lines[0]}" = "123"
  
  run resolve_prefix_element 4 "$ref"
  test "${lines[0]}" = "<4>"
  
  run resolve_prefix_element 5 "$ref"
  test "${lines[0]}" = "<5>"
  
  run resolve_prefix_element 6 "$ref"
  test "${lines[0]}" = "<6>"
  
  run resolve_prefix_element 7 "$ref"
  test "${lines[0]}" = "<7>"
  
  run resolve_prefix_element 8 "$ref"
  test "${lines[0]}" = "<8>"
  
  run resolve_prefix_element 9 "$ref"
  test "${lines[0]}" = "<9>"
  
  run resolve_prefix_element 10 "$ref"
  test "${lines[0]}" = "<10>"
  
  run resolve_prefix_element 11 "$ref"
  test "${lines[0]}" = " Comment" \
    || fail "${lines[0]}"
}



