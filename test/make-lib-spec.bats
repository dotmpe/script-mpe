#!/usr/bin/env bats

base=make.lib
load init

testf1=test/var/make/test-1-targets.mk
testf2_1=test/var/make/test-2-variables-1.mk
testf2_2=test/var/make/test-2-variables-2.mk
testf2_3=test/var/make/test-2-variables-3.mk
testf2_4=test/var/make/test-2-variables-4.mk

setup()
{
  init && lib_load make
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

@test "${base}: htd-make-vardef" {

  run htd_make_vardef "VAR1_1a" "$testf2_1"
  test_ok_nonempty 1 || stdfail F2.1a "\$(VAR1a)"

  run htd_make_vardef "VAR1a" "$testf2_1"
  { test_ok_nonempty 1 && test_lines "foo"
  } || stdfail F2a

  run htd_make_vardef "VAR1_1b" "$testf2_1"
  { test_ok_nonempty 1 && test_lines '$(VAR1a)'
  } || stdfail F2.1b
}

@test "${base}: htd-make-list{-internal,}-vars" {

  run htd_make_list_internal_vars "$testf1"
  test_ok_nonempty 35 || stdfail 1.A.

  run htd_make_list_vars "$testf1"
  test_ok_empty || stdfail 1.B.

  run htd_make_list_vars "$testf2_1"
  { test_ok_nonempty 6 && test_lines 'VAR1_1a' 'VAR1a' 'VAR1_1b'
  } || stdfail 2.1
  run htd_make_list_vars "$testf2_2"
  { test_ok_nonempty 4 && test_lines 'VAR2_1a' 'VAR2_1b' 'VAR2_2a' 'VAR2_2b'
  } || stdfail 2.2.
  run htd_make_list_vars "$testf2_3"
  { test_ok_nonempty 3 && test_lines 'VAR3_1' 'VAR3_2' 'VAR3_3'
  } || stdfail 2.3.
  run htd_make_list_vars "$testf2_4"
  { test_ok_nonempty 2
  } || stdfail 2.4.

  run htd_make_list_internal_vars "$testf2_1"
  { test_ok_nonempty 41 && test_lines 'VAR1_1a' 'VAR1a' 'VAR1_1b'
  } || stdfail 2.1
  run htd_make_list_internal_vars "$testf2_2"
  { test_ok_nonempty 39 && test_lines 'VAR2_1a' 'VAR2_1b' 'VAR2_2a' 'VAR2_2b'
  } || stdfail 2.2.
  run htd_make_list_internal_vars "$testf2_3"
  { test_ok_nonempty 38 && test_lines 'VAR3_1' 'VAR3_2' 'VAR3_3'
  } || stdfail 2.3.
  run htd_make_list_internal_vars "$testf2_4"
  { test_ok_nonempty 37
  } || stdfail 2.4.
}

@test "${base}: htd-make-expand vars I" {

  run htd_make_expand "VAR1_1a" "$testf2_1"
  { test_ok_nonempty 1 && test_lines "foo"
  } || stdfail F2.1a

  run htd_make_expand "VAR1a" "$testf2_1"
  { test_ok_nonempty 1 && test_lines "foo"
  } || stdfail F2a

  run htd_make_expand "VAR1_1b" "$testf2_1"
  { test_ok_nonempty 1 && test_lines "foo"
  } || stdfail F2.1b

  run htd_make_expand "VAR1_2a" "$testf2_1"
  test_ok_empty || stdfail F2.1a

  run htd_make_expand "VAR1b" "$testf2_1"
  { test_ok_nonempty 1 && test_lines "foo"
  } || stdfail F2a

  run htd_make_expand "VAR1_2b" "$testf2_1"
  { test_ok_nonempty 1 && test_lines "foo"
  } || stdfail F2.1b
}

@test "${base}: htd-make-expand vars II" {

  load assert
  local testf_= lnr=0
  while read testf var value
  do
    lnr=$(( $lnr + 1 ))
    test -n "$testf" || continue
    test '"' != "$testf" || testf="$testf_"
    test -e "$testf" || error "No testfile '$testf' at line $lnr" 1
    test -n "$var" && {

      test "$(htd_make_expand "$var" "$testf")" = "$value" ||
        stdfail "$lnr: $var=$value"

      assert_equal "$lnr: $var=$(htd_make_expand "$var" "$testf" )" "$lnr: $var=$value"
    }
    testf_="$testf"
  done <"test/var/make/htd-make-expand-1.tab"
}

@test "${base}: htd-make-expand-all" {

  run htd_make_expand_all "$testf2_1"
  { test_ok_nonempty 6 && test_lines \
            VAR1_1b=foo \
            VAR1_2a= \
            VAR1_2b=foo \
            VAR1a=foo \
            VAR1b=foo \
            VAR1_1a=foo
  } || stdfail F2.1

  run htd_make_expand_all "$testf2_2"
  { test_ok_nonempty 4 && test_lines \
			VAR2_1a=foo \
			VAR2_1b=foo \
			VAR2_2a=foo\ bar-a-2 \
			VAR2_2b=foo\ bar-b-2
  } || stdfail F2.2

  run htd_make_expand_all "$testf2_3"
  { test_ok_nonempty 3 && test_lines \
     VAR3_1="test/var/make/test-*-*-3.mk" \
     VAR3_2=test/var/make/test-2-variables-3.mk \
     VAR3_3=test/var/make/test-2-variables-3.mk
  } || stdfail F2.3
}

@test "${base}: htd-make-srcfiles" {

  run htd_make_srcfiles
  { test_ok_nonempty 1 && test_lines "/dev/null"
  } || stdfail 1.

  run htd_make_srcfiles "$testf1"
  { test_ok_nonempty 1 && test_lines "$testf1"
  } || stdfail 2.

  run htd_make_srcfiles "$testf2_1"
  { test_ok_nonempty 1 && test_lines "$testf2_1"
  } || stdfail 3.
}
