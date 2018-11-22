#!/usr/bin/env bats

base=date.lib
load init

setup()
{
  init && lib_load date
}


@test "$base: BSD date takes multiple -v" {

  test "$uname" = "Darwin" || skip "Testing BSD/Darwin only" 1

  run date -v monday -v '-1d' "+%A"
  test_ok_nonempty "Sunday" || stdfail 0.1

  run date -v monday -v '+1w' "+%A"
  test_ok_nonempty "Monday" || stdfail 0.2
}

@test "$base: GNU date takes one -d (but uses last without complaint)" {

  run $gdate -d 'monday -1day' "+%A"
  test_ok_nonempty "Sunday" || stdfail 0.1

  run $gdate -d 'monday +1week' "+%A"
  test_ok_nonempty "Monday" || stdfail 0.2

  run $gdate -d 'monday +1week' -d 'monday +1day' "+%A"
  test_ok_nonempty "Tuesday" || stdfail 0.3
}
