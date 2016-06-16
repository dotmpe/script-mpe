#!/usr/bin/env bats

load helper
base=projectdir.sh

init
. $lib/util.sh


@test "${bin}" "default no-args" {
  case $(current_test_env) in travis )
      TODO "$BATS_TEST_DESCRIPTION at travis";;
  esac
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
}


@test "${bin} help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*projectdir.sh <cmd> *" "${lines[*]}"
}


@test "${bin} regenerate" {
  tmpd
  {
    echo 'package_pd_meta_check=":bats-specs"'
    echo 'package_pd_meta_test=":bats-specs :bats"'
    echo package_pd_meta_git_hooks_pre_commit=./tools/ci/pre-commit.sh
  } > $tmpd/.package.sh
  cd $tmpd
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0 \
    || fail "Stat: ${status}, Out: ${lines[@]}"
  test -e tools/ci/pre-commit.sh
}

