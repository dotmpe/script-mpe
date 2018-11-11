#!/usr/bin/env bats
  
base=box
load init
init

setup()
{
  source $lib/util.sh
  pwd=$(pwd -P)

  usage_line_1="${base}.sh Bash/Shell script helper"
  usage_line_2="Usage:"
  usage_line_3="  ${base} <cmd> [<args>..]"
}

@test "$base: no arguments no-op" {

  test -n "${bin}" || stdfail "Exec $base expected"
  tmpd

  ENV_NAME="$(current_test_env)"
  # XXX: Env-Name
  #case "$ENV_NAME" in
  #    vs1 ) idx=0 num=4 ;;
  #    simza ) idx=1 num=8 ;;
  #    travis ) idx=0 num=8 ;;
  #    * ) idx=0 num=4 ;;
  #esac

  run $bin

  { test $status -eq 1 && fnmatch "*No command given*" "${lines[*]}"
  } || stdfail "$ENV_NAME, status"
}

@test "${bin} help" {
  test -n "${bin}"
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 && fnmatch "*Usage:*" "${lines[*]}" &&
    ( fnmatch "*Error:*" "${lines[*]}" && return 1 || return 0 )
  } || stdfail
  # FIXME:  fnmatch "*Commands:*" "${lines[*]}" # detailed usage on out
}

@test "${bin} -h" {
  skip "FIXME htd/main cmd alias"
  run $BATS_TEST_DESCRIPTION
  { test ${status} -eq 0 && fnmatch "*Usage:*" "${lines[*]}" &&
    ( fnmatch "*Error:*" "${lines[*]}" && return 1 || return 0 )
  } || stdfail
}

@test "${bin} -h help" {
  skip "FIXME htd/main cmd alias"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*Help 'help':*" "${lines[*]}" # manual on out
  fnmatch "*Usage: * box -h|help \[<id>]*" "${lines[*]}" # usage info on out
  fnmatch "*Error:*" "${lines[*]}" && test -z "errors in output" || true
}

@test "${bin} check-install" {
  skip "FIXME"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} -i" {
  skip "FIXME htd/main cmd alias"
  tmpd; testd=$tmpd/bats-test-spec-foo/bar/3/baz_4
  mkdir -vp $testd
  (
    cd $testd
    expect=_tmp_bats_test_spec_foo_bar_3_baz_4
    run $BATS_TEST_DESCRIPTION
  )
  { test $status -eq 0 && test "${#lines[@]}" = "8"; } || stdfail
}

# Dry Runs go successfully
@test "${bin} -vv -n init" {
  skip "FIXME htd/main cmd alias"
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
  skip "FIXME htd/main cmd alias"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  run ${bin} -vn edit
  skip "FIXME dry runs only work with verbosity on?"
  run ${bin} -nqq edit
  test $status -eq 0
  test -z "${lines[*]}"
}

@test "${bin} -v -n edit-main" {
  skip "FIXME htd/main cmd alias"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "${bin} -v -n new" {
  skip "FIXME htd/main cmd alias"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  skip "FIXME dry runs only work with verbosity on?"
  run ${bin} -n -qq new
  test $status -eq 0
  test -z "${lines[*]}"
}

@test "${bin} -vn run" {
  skip "FIXME htd/main cmd alias"
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

