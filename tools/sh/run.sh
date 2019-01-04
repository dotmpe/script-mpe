#!/usr/bin/env bash

# Build matrix experiment.

# XXX: cleanup, cons. run.sh +htdocs_mpe

scriptname=ci:run
. $scriptpath/tools/sh/run.inc.sh "$@"
lib_load build

build_matrix | while read params
do
  eval params
  $TEST_SHELL $TEST_FLOW
done

note "Done"

