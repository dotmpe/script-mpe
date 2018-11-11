#!/usr/bin/env bats

base=box-src
load init

setup()
{
  init
}


@test "htd src-info - prints (total) lines and functions" {
  run htd src-info test/var/sh-src-*.sh
  # NOTE: count (suppor for) one style of function declaration only
  test_ok_nonempty "*Functions*:*2.*" "*Lines*:*46" || stdfail
}

@test "htd functions list " {
  run htd functions list test/*.bash
  test_ok_nonempty || stdfail
  #test_ok_lines "fail*" "diag*" "setup_clean_git\(\)" || stdfail
}

@test "htd filter-functions" {

  TODO fixme
  export verbosity=5

  run $BATS_TEST_DESCRIPTION "grp=\(box\|htd\)* run=[a-z].*" htd
  #diag "lines=${#lines[*]}"
  # FIXME: find definition and update test_ok_nonempty 70 || stdfail 1-default
  test_ok_nonempty || stdfail 1-default

  export Inclusive_Filter=1
  run $BATS_TEST_DESCRIPTION "grp=box-src spc=..*" htd
  { test_ok_nonempty && 
    fnmatch "* list-functions *" " ${lines[*]} " &&
    fnmatch "* find-functions *" " ${lines[*]} " &&
    fnmatch "* filter-functions *" " ${lines[*]} " &&
    fnmatch "* checkout *" " ${lines[*]} "
  } || stdfail 2-inclusive

  export Inclusive_Filter=0
  run $BATS_TEST_DESCRIPTION "grp=box-src spc=..*" htd
  { test_ok_nonempty && 
    fnmatch "* list-functions *" " ${lines[*]} " &&
    fnmatch "* filter-functions *" " ${lines[*]} " && {
      fnmatch "* crypto *" " ${lines[*]} " && return 1 || true
    } && {
      fnmatch "* checkout *" " ${lines[*]} " && return 1 || true
    }
  } || stdfail 3-exclusive
}


# find-functions grep scripts
# find-function grep scripts
