#!/usr/bin/env bats

base=basename-reg

load helper

# TODO configure which fields it outputs

@test "$bin ffnenc.py" {
  test -z "$TRAVIS_SKIP" || skip "FIXME $BATS_TEST_DESCRIPTION"
  run $BATS_TEST_DESCRIPTION
  #out="ffnenc.py       ffnenc  py      text/x-python   py      Script  Python script text"
  test $status -eq 0
}

@test "$bin ffnenc.py -O csv" {
  test -z "$TRAVIS_SKIP" || skip "FIXME $BATS_TEST_DESCRIPTION"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${lines[0]}" = "ffnenc.py,ffnenc,py,text/x-python,py,Script,Python script text"
}
