#!/usr/bin/env bats

base=make.lib
load init

testf1=test/var/make.mk

setup()
{
  init 0 &&
  load helper-extra &&
  load helper-stdtest &&
  lib_load make
}

@test "${base}: make-dump-nobi $testf1" {

  run make_dump_nobi "$testf1"
  { test_ok_nonempty && test_lines \
    "default:" \
    "target-1: prereq-1 prereq-2" \
    "target-2:: prereqs" \
    "target-1a: var := foo" \
    "target-2a: var := foo" \
    "target-3a:" \
    "target-3b:"
  } || stdfail
}

@test "${base}: make-dump-nobi $testf1 | make-targets" {

  _() { make_dump_nobi "$testf1" | make_targets; }
  run _
  { test_ok_nonempty && test_lines \
    "default:" \
    "target-1:" \
    "target-2::" \
    "target-1a:" \
    "target-2a:" \
    "target-3a:" \
    "target-3b:"
  } || stdfail
}
