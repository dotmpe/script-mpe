#!/usr/bin/env bats

load init

base=basename-reg
init

setup()
{
  test -e "$HOME/.basename-reg.yaml" || touch "$HOME/.basename-reg.yaml"
}


@test "$bin --help" {
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin -c ffnenc.py" {

  run $BATS_TEST_DESCRIPTION
  { test_ok_nonempty 1 && test_lines "ffnenc.py  py"
  } || stdfail
}

@test "$bin -o csv -c ffnenc.py" {

  run $BATS_TEST_DESCRIPTION
  { test_ok_nonempty 1 && test_lines "ffnenc.py,py"
  } || stdfail
}
