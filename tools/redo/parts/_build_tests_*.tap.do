#!/usr/bin/env bash
set -euo pipefail
test -d .build/tests || mkdir .build/tests
set -- "$@" test/$(basename -- "$1" .tap).bats
test -e "$4" || exit 20

local r
{
  bats "$4"  || r=$?
} |
if test ${build_ci_tests_quiet:-${quiet-0}} -eq 1
then cat >"$3"
else tee "$3" | ./tools/sh/bats-colorize.sh >&2; fi

build-stamp <"$3"

return ${r:-}
# TODO: handle test<->component and dependency mapping somewhere in buildsys
#CWD=$REDO_BASE . $REDO_BASE/tools/sh/init.sh &&
#  lib_load &&
#  scriptname="do:$REDO_PWD:$1" &&
#  cd "$REDO_BASE" &&
#  lib_load build-test &&
#  build_test_init &&
#  paths="$( component_depnames "$5" | words_to_lines )"
#
#test -z "$paths" || {
#  redo-ifchange $paths || exit $?
#}
#build_test "$5" >"$4"
# Sync: U-S:
