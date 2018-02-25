#!/usr/bin/env bats

base=box-src
load init
init

@test "htd src-info - prints (total) lines and functions in htd" {
  run htd src-info
  test_ok_nonempty "*Functions*:*379.*" "*Lines*:*" || stdfail
}

@test "htd src-info - prints total functions in scripts" {
  run htd src-info box-instance.sh
  test_ok_nonempty "*Total?Functions*9*" "Total?Lines*157*" || stdfail
}

@test "htd list-functions" {
  run htd list-functions test/*.bash
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
      fnmatch "* crypto *" " ${lines[*]} " && return 1 || noop
    } && {
      fnmatch "* checkout *" " ${lines[*]} " && return 1 || noop
    }
  } || stdfail 3-exclusive
}


# find-functions grep scripts
# find-function grep scripts


#@test "${lib}/${base} - function should ..." {
#  check_skipped_envs || \
#    TODO "envs $envs: implement lib (test) for env" # tasks-ignore
#  diag $BATS_TEST_DESCRIPTION
#  run function args
#  test true || fail
#  test_ok_empty || stdfail
#  test_ok_nonempty || stdfail
#  test_ok_nonempty "*match*" || stdfail
#  { test_nok_nonempty "*match*" &&
#    test ${status} -eq 1 &&
#    fnmatch "*other*" &&
#    test ${#lines[@]} -eq 3
#  } || stdfail
#}

