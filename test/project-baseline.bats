#!/usr/bin/env bats

base='baseline:3:project'


@test "$base: init.sh setup" {

  run . ./tools/sh/init.sh
  test $status -eq 0 && test -z "${lines[*]}"

  # Again, no harnass.
  . ./tools/sh/init.sh
}

@test "$base: tools/sh/log" {

  load ../init
  load extra
  load stdtest
  LOG=tools/sh/log.sh

  run $LOG tag1 tag2 msg tag3 0
  { test_ok_nonempty 1 && test_lines ' msg <tag3>'
  } || stdfail "1.A. '${lines[0]}'"

  run $LOG tag1 tag2 msg tag3 1
  { test_nok_nonempty 1 && test_lines " msg <tag3>"
  } || stdfail 1.B.

  run $LOG ok "tag1 tag2" "A longer message" "tag3 tag4"
  { test_ok_nonempty 1 &&
    test_lines '\[tag1 tag2] OK: A longer message <tag3 tag4>'
  } || stdfail "1.A.2 '${lines[0]}'"

  run $LOG tag1 tag2 msg tag3 0
  test_ok_nonempty || stdfail 2.
}
