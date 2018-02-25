#!/usr/bin/env bats

load init
base=./rsr.py

init


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

db_path=/srv/project-mpe/script-mpe/.cllct/cllct_2012.sqlite

@test "${bin} --init-db" {
  skip "FIXME:"
  test -e $(dirname $db_path) || mkdir $(dirname $db_path)
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test -e $db_path
  rm $db_path
  rm -rf $(dirname $db_path)
  #test -n "${lines[*]}" # non-empty output
}


@test "${bin} . with db_sa.py" {
  test -e $(dirname $db_path) || mkdir $(dirname $db_path)
  db_sa.py -d $db_path init rsr
  run ${bin} .
  test ${status} -eq 0
  test -e $db_path
  rm $db_path
  rm -rf $(dirname $db_path)
  #test -n "${lines[*]}" # non-empty output
}
