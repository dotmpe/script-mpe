#!/usr/bin/env bats

load helper
base=projectdir.sh

init
. $lib/util.sh



test_args_shift_1()
{
  # Shift first argument to third place if only one given

  test -z "$1" || {
    test -n "$2" || set -- "" "$1"
  }

  echo "1:$1 2:$2"
}

@test "argument defaults, shift to 2" {

  run test_args_shift_1 a b
  #diag "${lines[*]}"
  fnmatch "1:a 2:b" "${lines[*]}"
  run test_args_shift_1 a
  fnmatch "1: 2:a" "${lines[*]}"
  run test_args_shift_1 "" b
  fnmatch "1: 2:b" "${lines[*]}"
}


test_args_shift_2()
{
  # Shift as long as desired argument length
  while test ${#} -ne 3
  do
    set -- "" "$@"
  done

  echo "1:$1 2:$2 3:$3"
}

@test "argument defaults, shift to 3" {

  run test_args_shift_2 a b c 
  fnmatch "1:a 2:b 3:c" "${lines[*]}"
  run test_args_shift_2 a b
  fnmatch "1: 2:a 3:b" "${lines[*]}"
  run test_args_shift_2 a
  fnmatch "1: 2: 3:a" "${lines[*]}"
  diag "${lines[*]}"
}

# vim:ft=bash:
