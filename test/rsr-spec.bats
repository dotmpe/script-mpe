#!/usr/bin/env bats

load init
base=./rsr.py

init


setup()
{
  test -n "$scriptpath" || error scriptpath 1
  db_path=$scriptpath/.cllct/cllct_2012_test.sqlite
}

teardown()
{
  test -n "$db_path"
  rm -rf $(dirname $db_path)
}

@test "${bin} --help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
}

@test "${bin} -vv -h" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -n "${lines[*]}" # non-empty output
}

@test "${bin} --init-db" {
  test -e $(dirname $db_path) || mkdir $(dirname $db_path)
  # touch/format DB file
  sqlite3 $db_path ".databases" >/dev/null
  run $BATS_TEST_DESCRIPTION --dbref=sqlite:///$db_path
  { test_ok_nonempty && test -e $db_path ; } || stdfail
}

@test "${bin} . with db_sa.py" {
  test -e $(dirname $db_path) || mkdir $(dirname $db_path)
  db_sa.py -d $db_path init rsr
  run rsr.py --dbref=sqlite:///$db_path .
  { test_ok_nonempty && test -e $db_path ; } || stdfail
}
