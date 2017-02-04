#!/bin/sh

set -e
test -n "$scriptdir" || 219


# Init

scriptname=ci:run
. $scriptdir/tools/sh/run.inc.sh "$@"
lib_load build

build_matrix | while read params
do
  eval params
  $TEST_SHELL $TEST_FLOW
done

