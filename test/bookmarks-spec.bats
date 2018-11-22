#!/usr/bin/env bats

load init

base=bookmarks.py
init

setup()
{
  true
}


@test "$bin --help" {
  run $BATS_TEST_DESCRIPTION
  test_ok_lines "Usage:" \
      "*  $bin --background" \
      "*  $bin -h*--help" \
      "*  $bin help *" \
      "*  $bin --version" || stdfail
}


#@test "$bin list" {
#  run $BATS_TEST_DESCRIPTION
#  test_ok || stdfail
#}
#
#
#@test "$bin list --tags=XXX" {
#  run $BATS_TEST_DESCRIPTION
#  test_ok || stdfail
#}


# bookmarks.py list --output-format=rst --tags=todo --count
