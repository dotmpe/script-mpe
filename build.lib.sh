#!/bin/sh

set -e


# TODO
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
  local verbosity=4
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


test_features()
{
  ./vendor/.bin/behat --tags '~@todo&&~@skip&&~@skip.travis'
}
