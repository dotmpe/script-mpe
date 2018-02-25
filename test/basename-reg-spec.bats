#!/usr/bin/env bats

load init

base=basename-reg
init

setup()
{
  # TODO configure which fields it outputs
  test -e "$HOME/.basename-reg.yaml" || touch "$HOME/.basename-reg.yaml"
}

@test "$bin --help" {
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin ffnenc.py" {

  TODO "fix sqlalchemy"

  check_skipped_envs travis || \
    TODO "envs $envs: implement bin (test) for env"

  run $BATS_TEST_DESCRIPTION
  #out="ffnenc.py       ffnenc  py      text/x-python   py      Script  Python script text"
  test $status -eq 0
}

@test "$bin ffnenc.py -O csv" {

  TODO "fix sqlalchemy"

  check_skipped_envs travis || \
    skip "TODO envs $envs: implement bin (test) for env"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${lines[0]}" = "ffnenc.py,ffnenc,py,text/x-python,py,Script,Python script text"
}

