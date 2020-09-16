#!/usr/bin/env bash
set -euo pipefail
test -d .build/tests || mkdir .build/tests
set -- "$@" test/$(basename -- "$1" .tap).bats
test -e "$4" || exit 20

#echo 3:$3 >&2
if test ${build_ci_tests_quiet:-${quiet-0}} -eq 1
then
    bats "$4" > "$3"
else
    bats "$4" | tee "$3" | ./tools/sh/bats-colorize.sh >&2
fi

{
  ls -la "$3"
  wc -l "$3"
} >&2

build-stamp <"$3"
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
#
