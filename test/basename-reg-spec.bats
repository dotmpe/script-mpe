#!/usr/bin/env bats

bin=basename-reg

load helper

# TODO configure which fields it outputs

@test "$bin ffnenc.py" {
  run $BATS_TEST_DESCRIPTION
  #out="ffnenc.py       ffnenc  py      text/x-python   py      Script  Python script text"
  test $status -eq 0
}

@test "$bin ffnenc.py -O csv" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${lines[0]}" = "ffnenc.py,ffnenc,py,text/x-python,py,Script,Python script text"
}
