#!/usr/bin/env bats

load init

setup()
{
  init && load stdtest
}

@test "./treemap3.py help" {

  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail

  for opt in "--help" "-h"
  do
    run ./treemap3.py $opt
    { test_ok_nonempty && test_lines "*Usage:*" "*Options:*"
    } || stdfail "$opt"
  done
}

@test "./treemap3.py tree doc" {

  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "./treemap3.py size test/var/treemap/test.file" {

  run ./treemap3.py size test/var/treemap/test.file
  { test_ok_nonempty && test "${lines[*]}" = "15"
  } || stdfail "$opt"

  for opt in -H --human-readable
  do
    run ./treemap3.py $opt size test/var/treemap/test.file
    { test_ok_nonempty && test "${lines[*]}" = "15"
    } || stdfail "$opt"
  done
}

@test "./treemap3.py size DIR" {

    for DIR in test/var/build-lib test/var/esop test/var/jsotk test/var/treemap doc
    do
      bytes=$(find $DIR -type f -exec stat -c '%s' {} \; | paste -sd+ - | bc)

      run ./treemap3.py size $DIR
      { test_ok_nonempty && test "${lines[*]}" = "$bytes"
      } || stdfail "DIR:$DIR size was not $bytes"
    done
}
