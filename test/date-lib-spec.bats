#!/usr/bin/env bats

base=date.lib
load init
init

setup()
{
  load stdtest extra && lib_require date date-htd
}


@test "${base}: date-id" {

  dt=$( $gdate -u --iso=date -d @1519855200 )
  run date_id $dt
  { test_ok_nonempty && test "${lines[*]}" = "20180228+01" ; } || stdfail

  run date_id 1539008984
  { test_ok_nonempty && test "${lines[*]}" = "20181008-1629+02" ; } || stdfail
}

@test "${base}: date-idp" {

  run date_idp "20180101+02"
  { test_ok_nonempty && test "${lines[0]}" = "2018-01-01T00+02" ; } || stdfail
  run date_idp "20180301+02"
  { test_ok_nonempty && test "${lines[0]}" = "2018-03-01T00+02" ; } || stdfail
  run date_idp "20180301+01"
  { test_ok_nonempty && test "${lines[0]}" = "2018-03-01T00+01" ; } || stdfail

  run date_idp "20180101-01+02"
  { test_ok_nonempty && test "${lines[0]}" = "2018-01-01T01+02" ; } || stdfail
  run date_idp "20180101-0101+02"
  { test_ok_nonempty && test "${lines[0]}" = "2018-01-01T01:01+02" ; } || stdfail
  run date_idp "20180101-010101+02"
  { test_ok_nonempty && test "${lines[0]}" = "2018-01-01T01:01:01+02" ; } || stdfail
}

@test "${base}: date-pstat" {

  run date_pstat "20180301+01"
  { test_ok_nonempty && test "${lines[0]}" = "1519858800" ; } || stdfail

  run date_pstat "20180101"
  { test_ok_nonempty && test "${lines[0]}" = "1514761200" ; } || stdfail

  run date_pstat "20180101+01"
  { test_ok_nonempty && test "${lines[0]}" = "1514761200" ; } || stdfail

  run date_pstat "20180101-01+01"
  { test_ok_nonempty && test "${lines[0]}" = "1514764800" ; } || stdfail

  run date_pstat "20180101-0101+01"
  { test_ok_nonempty && test "${lines[0]}" = "1514764860" ; } || stdfail

  run date_pstat "20180101-010101+01"
  { test_ok_nonempty && test "${lines[0]}" = "1514764861" ; } || stdfail
}

@test "$base: date-fmt" {

  run date_fmt '-1d' '%A'
  test_ok_nonempty || stdfail A.1
  run date_fmt 'today' '%A'
  test_ok_nonempty || stdfail A.2
  run date_fmt '+1d' '%A'
  test_ok_nonempty || stdfail A.3

  run date_fmt 'monday +1d' '%A'
  test_ok_nonempty || stdfail B.1
  run date_fmt 'monday +1w' '%A'
  test_ok_nonempty || stdfail B.2
  run date_fmt 'monday +7d' '%A'
  test_ok_nonempty || stdfail B.3
}
