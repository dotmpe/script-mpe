#!/bin/sh

set -e


build_matrix()
{
  echo
}


test_specs()
{
  for SPEC in $SUITE
    do
      test ! -e ./test/$SPEC-spec.bats || echo ./test/$SPEC-spec.bats
  done
}

test_shell()
{
  test -n "$*" || set -- bats
  note "test-shell '$*' SUITE='$SUITE'"
  test -n "$SUITE" && {
    SPECS="$(test_specs | lines_to_words)"
  } || {
    test -n "$SPEC" && {
      SPECS="./test/$SPEC-spec.bats"
    } || {
      SPECS=./test/*-spec.bats
    }
  }
  note "test-shell '$*' SPECS='$SPECS'"
  eval $@ $SPECS
}

run_spec()
{
  test -n "$1" || set -- bats
  R=0
  ( $1 --tap test/$spec-spec.bats || R=$? ) | sed 's/^/    /g' > $tmp 2>&1
  test $R -eq 0 && {
    echo "ok $I $spec "
    echo "ok $I $spec " >> $TEST_RESULTS
  } || {
    echo "not ok $I $spec (returned $R)"
    echo "not ok $I $spec (returned $R)" >> $TEST_RESULTS
    echo $spec >> $failed
  }
  cat $tmp >> $TEST_RESULTS
}


test_features()
{
  behat --tags '~@todo&&~@skip&&~@skip.travis'
}


