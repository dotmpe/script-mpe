#!/usr/bin/env bats

base=box
load helper
init
source $lib/util.sh
pwd=$(cd .;pwd -P)


usage_line_1="${base}.sh Bash/Shell script helper"
usage_line_2="Usage:"
usage_line_3="  ${base} <cmd> [<args>..]"


@test "$bin no arguments no-op" {

  check_skipped_envs travis || skip "FIXME broken after main.lib.sh rewrite"

  #echo "${lines[*]}" > /tmp/1
  #echo "${#lines[@]}" >> /tmp/1

  tmpd
  #tmp=$(cd $tmpd/;pwd -P)
  #run bash -c 'cd '$tmp'/ && '$pwd/${bin}
  run $bin
  lines_to_file $tmpd/1
  echo "env $(current_test_env)" >> $tmpd/1
  echo "status $status" >> $tmpd/1
  echo "lines ${#lines[@]}" >> $tmpd/1
  test $status -eq 1
  return

  case "$(current_test_env)" in
      vs1 ) idx=0 num=4 ;;
      simza ) idx=1 num=8 ;;
      travis ) idx=0 num=8 ;;
      * ) idx=0 num=8 ;;
  esac

  # TODO: Meh.. test [[ "${lines[0]}" =~ "No.script.for" ]]
  #fnmatch "*No local script for*" "${lines[$idx]}" || test
  #skip "FIXME ${bin} should default to run, currently it doesnt"
  echo "${lines[$idx]}" | grep No.local.script.for || test
  test "${#lines[@]}" = "$num"
}

@test "${bin} help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
# FIXME:  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}

@test "${bin} -h" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Usage:*" "${lines[*]}" # usage info on out
# FIXME:  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}

@test "${bin} -h help" {
  #is_skipped pd && skip "FIXME specs not working OK" || printf ""
  #check_skipped_envs simza || skip "FIXME $envs: not running on $env"

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Help 'help':*" "${lines[*]}" # manual on out
  fnmatch "*Usage: * box -h|help \[<id>]*" "${lines[*]}" # usage info on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || noop
}

@test "${bin} check-install" {
  skip "while rewriting main routines"
  check_skipped_envs travis || skip "FIXME $envs: not running on $env"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} -i" {
  skip "FIXME"
  tmpd
  tmpf=$tmpd/bats-test-spec-foo/bar/3/baz_4
  #tmpf
  mkdir -vp $tmpf
  pushd $tmpf
  expect=_tmp_bats_test_spec_foo_bar_3_baz_4
#  run $BATS_TEST_DESCRIPTION
  popd
#  test $status -eq 0
#  test "${#lines[@]}" = "8"
#test -e ""
}

# Dry Runs go successfully
@test "${bin} -vv -n init" {
  skip "FIXME"
  is_skipped pd && skip "FIXME: Something with stdin maybe" || printf ""
  check_skipped_envs simza travis || skip "FIXME: $envs: not running on $env"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  skip "fix options"
  run ${bin} -nqq init
  test $status -eq 0
  test -z "${lines[*]}"
}

@test "${bin} -vvv -n edit" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  run ${bin} -vn edit
  skip "FIXME dry runs only work with verbosity on?"
  run ${bin} -nqq edit
  test $status -eq 0
  test -z "${lines[*]}"
}

@test "${bin} -v -n edit-main" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} -v -n new" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  skip "FIXME dry runs only work with verbosity on?"
  run ${bin} -n -qq new
  test $status -eq 0
  test -z "${lines[*]}"
}

@test "${bin} -vn run" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} -vn -r" {
  TODO "no opts for subcmds yet"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}


@test "${bin} -rg" {
  skip "$BATS_TEST_DESCRIPTION TODO: test and code run-global"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} -r" {
  skip "$BATS_TEST_DESCRIPTION TODO: test and code run (local)"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} -n" {
  skip "$BATS_TEST_DESCRIPTION TODO: test and code new"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} -c" {
  skip "$BATS_TEST_DESCRIPTION TODO: test and code create"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} -d" {
  skip "$BATS_TEST_DESCRIPTION TODO: test and code deinit"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} list-libs" "lists the includes of a named file" {

  skip "FIXME: $BATS_TEST_DESCRIPTION"
  #is_skipped pd && skip "FIXME: Something with stdin maybe"
  #check_skipped_envs travis || skip "FIXME broken after main.lib.sh rewrite"

  run $BATS_TEST_DESCRIPTION

  tmpd
  case "$(current_test_env)" in

    simza )
      test $status -eq 0
      echo "lines ${#lines[@]}" > $tmpd/1
      test "${#lines[@]}" = "8" # lines of output (stderr+stderr)
      ;;

    vs1 )
      test $status -eq 0
      #echo "lines ${#lines[@]}" > $tmpd/1
      test "${#lines[@]}" = "7" # lines of output (stderr+stderr)
      ;;

    * )
      diag "Unknown env $(current_test_env), status ${status}"
      test $status -eq 3
      test "${#lines[@]}"
      skip "FIX testing at travis"
      test "${#lines[@]}" = "2" # lines of output (stderr+stderr)
      ;;

  esac
}

