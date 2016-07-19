#!/usr/bin/env bats

load helper
base=projectdir.sh

init
. $lib/util.sh


@test "${bin}" "0.1.1.1 default no-args" {
  case $(current_test_env) in travis )
      TODO "$BATS_TEST_DESCRIPTION at travis";;
  esac
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
}


@test "${bin} help" "0.1.1.2"  {
  skip "Something wrong with pd/std__help"
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "*$base <cmd> *" "${lines[*]}"
}


@test "${bin} regenerate" "0.1.4. - generates pre-commit hook from a .package.sh" {
  tmpd
  {
    echo 'package_pd_meta_check=":bats-specs"'
    echo 'package_pd_meta_test=":bats-specs :bats"'
    echo package_pd_meta_git_hooks_pre_commit=./tools/ci/pre-commit.sh
  } > $tmpd/.package.sh
  cd $tmpd
  git init
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0 \
    || fail "Stat: ${status}, Out: ${lines[@]}"
  test -e tools/ci/pre-commit.sh
  cd ..
  rm -rf $tmpd
}


@test "${bin} show" "" {

  run $BATS_TEST_DESCRIPTION
  test $status -eq 0

  test ${#lines[@]} -gt 25
  fnmatch "*repositories:*" "${lines[*]}"
  fnmatch "*package: * main: *" "${lines[*]}"
}


setup_empty_pd()
{
  tmpd
  testpd="test/var/pd/$testid.yaml"
  test -e "test/var/pd/$testid.yaml" && {
    cp $testpd $tmpd/.projects.yaml
  } || {
    { cat <<EOF
repositories:
  empty:
    remotes: {}
    sync: false
    clean: untracked
EOF
    } > $tmpd/.projects.yaml
  }
  mkdir $tmpd/empty
  cd $tmpd/empty
}


@test "${bin} ls-targets check" "Reads .pd-checks" {

  export verbosity=0

  setup_empty_pd
  {
    echo :vchk
    echo :bats-specs
  } > .pd-check

  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  rm .pd-check

  test ${#lines[@]} -eq 2 \
    || fail "${#lines[@]} Out: ${lines[*]}"

  test "${lines[0]}" = ":vchk"
  test "${lines[1]}" = ":bats-specs"

  cd ..
  rm -rf $tmpd
}


@test "${bin} ls-targets test" "Reads .pd-test, and autodetect test targets" {

  export verbosity=0

  setup_empty_pd
  {
    echo :vchk
  } > .pd-test

  diag "tmpd=$tmpd"
  
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0

  test ${#lines[@]} -eq 1 \
    || fail "${#lines[@]} Out: ${lines[*]}"

  test "${lines[0]}" = ":vchk"
  rm .pd-test

  touch Makefile
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test ${#lines[@]} -eq 1
  test ${lines[0]} = :make:test
  
  touch Gruntfile.js
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test ${#lines[@]} -eq 2
  test ${lines[0]} = :grunt:test
 
  mkdir test/; touch test/foo-spec.bats
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0 \
    || fail "Out: ${lines[*]}"
  test ${#lines[@]} -eq 3 \
    || fail "${#lines[@]} Lines Out: ${lines[*]}"
  test "${lines[0]}" = ":bats"
  test "${lines[1]}" = ":grunt:test"
  test "${lines[2]}" = ":make:test"

  { echo package=foo; } > .package.sh
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test ${#lines[@]} -eq 3 \
    || fail "${#lines[@]} Out: ${lines[*]}"
  test ${lines[0]} = :bats

# FIXME:
  #{ echo package_pd_meta_test=:foo; } > .package.sh
  #run $BATS_TEST_DESCRIPTION
  #test $status -eq 0
  #diag "${#lines[@]} Out: ${lines[*]}"
  #test ${#lines[@]} -eq 1
  #test ${lines[0]} = :foo

  { echo :pd-test-xxx; } > .pd-test
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test ${#lines[@]} -eq 1
  test ${lines[0]} = :pd-test-xxx

  rm -rf test Gruntfile .pd-test Makefile .package.sh

  cd ..
  rm -rf $tmpd
}



