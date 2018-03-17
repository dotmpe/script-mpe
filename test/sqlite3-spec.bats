#!/usr/bin/env bats


setup()
{
  testdb=.build/sqlite3-test.db
  test ! -e $testdb
}

teardown()
{
  test ! -e $testdb || rm $testdb
}

# Darwin/Homebrew sqlite 3.8.10.2 2015-05-20 18:17:19 2ef4f3a5b1d1d0c4338f8243d40a2452cc1f7fe4

@test "sqlite3 3.8 does not create DB file" {

  echo "" | sqlite3 .build/sqlite3-test.db
  test ! -e $testdb
}

@test "sqlite3 3.8 '.q' does not create DB file" {

  echo ".q" | sqlite3 $testdb
  test ! -e $testdb

  sqlite3 $testdb ".q"
  test ! -e $testdb
}

@test "sqlite3 3.8 '.databases' does create DB file" {

  echo ".databases" | sqlite3 $testdb
  test -e $testdb && rm $testdb

  sqlite3 $testdb ".databases"
  test -e $testdb && rm $testdb
}

@test "sqlite3 3.8 '.schema' does create DB file" {

  echo ".schema" | sqlite3 $testdb
  test -e $testdb && rm $testdb

  sqlite3 $testdb ".schema"
  test -e $testdb && rm $testdb
}

#@test "${lib}/${base} - function should ..." {
#  check_skipped_envs || \
#    TODO "envs $envs: implement lib (test) for env" # tasks-ignore
#  diag $BATS_TEST_DESCRIPTION
#  run function args
#  test true && pass || fail
#  test_ok_empty || stdfail
#  test_nok_empty || stdfail
#  test_nonempty || stdfail
#  test_ok_nonempty "*match*" || stdfail
#  { test_nok_nonempty "*match*" &&
#    test ${status} -eq 1 &&
#    fnmatch "*other*" &&
#    test ${#lines[@]} -eq 3
#  } || stdfail
#  test_lines, test_ok_lines, test_nok_lines
#}

