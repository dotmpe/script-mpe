#!/usr/bin/env bats

load init
base=redo-baseline

setup()
{
  # Undo parent redo env for test
  unset REDO_STARTDIR REDO_UNLOCKED REDO REDO_DEPTH REDO_RUNID \
        REDO_TARGET REDO_BASE REDO_LOCKS REDO_PWD REDO_NO_OOB &&
  init &&
  load assert &&
  lib_load setup-sh-tpl date &&
  tmpd &&
  diag "$BATS_TEST_NUMBER. Tmp-Dir: $tmpd ($BATS_TEST_DESCRIPTION)"
}

teardown()
{
  cd "$BATS_CWD"
  # remove tmpdir for clean tests
  test -n "$BATS_ERROR_STATUS" || rm -rf "$tmpd"
}

@test "$base: 1. redo{,-ifchange} builds, rebuilds; redo-{targets,sources,ood} lists; sqlite3 tracks deps" {

  test_tpl="test/var/redo/redo-baseline-tpl1.sh"
  setup_sh_tpl "$test_tpl" "" "$tmpd"

  cd "$tmpd"

  diag "$( env | grep REDO )"

  run redo-targets # Redo does not know any targets yet
  test_ok_empty || stdfail a.1.1.
  run redo-sources
  test_ok_empty || stdfail a.1.2.
  run redo-ood # Redo does not know any targets yet
  test_ok_empty || stdfail a.1.3.

  run redo my/second.test2
  test_ok_nonempty || stdfail a.2.

  run redo-targets
  { test_ok_nonempty 1 && test_lines "my/second.test2"
  } || stdfail a.2.1.
  run redo-sources
  { test_ok_nonempty 2 && test_lines "my/default.test2.do" "some.sh"
  } || stdfail a.2.2.
  run redo-ood
  { test_ok_empty
  } || stdfail a.2.3.

  rm my/*.test[0-9]

  run redo my/first.test1
  test_ok_nonempty || stdfail b.
  assert_file_exist "my/first.test1"
  assert_file_exist "my/second.test2"
  assert_equal "$(cat "my/first.test1")" 'Test1 done'
  assert_equal "$(cat "my/second.test2")" 'Test2 done: foo'

  run redo-targets
  { test_ok_nonempty 2 && test_lines "my/first.test1" "my/second.test2"
  } || stdfail b.2.1.
  run redo-sources
  { test_ok_nonempty 3 && test_lines "my/default.test1.do" "my/default.test2.do" "some.sh"
  } || stdfail b.2.2.
  run redo-ood
  test_ok_empty || stdfail b.2.3.


  echo "my_sh_var=bar" >"some.sh"

  run redo-ood
  { test_ok_nonempty 2 && test_lines my/first.test1 my/second.test2
  } || stdfail c.1.

  run redo-ifchange my/second.test2
  test_ok_nonempty || stdfail c.1.2.
  assert_equal "$(cat "my/second.test2")" 'Test2 done: bar' 


  echo "echo Test3 done" >>"my/default.test2.do"

  run redo-ood
  { test_ok_nonempty 2 && test_lines my/first.test1 my/second.test2
  } || stdfail c.2.

  run redo-ifchange my/first.test1
  test_ok_nonempty || stdfail c.2.2.
  assert_equal "$(cat "my/second.test2")" 'Test2 done: bar
Test3 done'


  lib_load redo
  #redo_lib_load

  run redo_deps "my/first.test1"
  { test_ok_nonempty 3 && test_lines \
      "my/second.test2 1" \
      "my/first.test1.do " \
      "my/default.test1.do 0"
  } || stdfail d.1.

  run redo_deps "my/second.test2"
  { test_ok_nonempty 3 && test_lines \
      "my/second.test2.do " \
      "my/default.test2.do 0" \
      "some.sh 0"

  } || stdfail "d.2."
}


@test "$base: 2. redo-stamp to avoid rebuilding all targets unnecessarily" {

#  skip 'TODO: if do-script runs and output is no different to lasttime; redo-stamp <$3...'

  test_tpl="test/var/redo/redo-baseline-tpl2.sh"
  setup_sh_tpl "$test_tpl" "" "$tmpd"

  cd "$tmpd"

  redo test.c
  exp_a="$(stat -f '%c' test.a)" ;
  exp_b="$(stat -f '%c' test.b)"
  exp_c="$(stat -f '%c' test.c)"
  stat -f '%N c:%c m:%m' test.* a.src

  sleep 1.5

  touch a.src
  redo-ifchange test.c
  test_a="$(stat -f '%c' test.a)" ;
  test_b="$(stat -f '%c' test.b)"
  test_c="$(stat -f '%c' test.c)"
  stat -f '%N c:%c m:%m' test.* a.src

  test "$test_a" != "$exp_a"
  assert_equal "$test_b" "$exp_b"
  assert_equal "$test_c" "$exp_c"
}


@test "$base: 3. Redo isolates env, and has no-reuse or export between .do files" {
  cd "$tmpd"
  SCRIPTPATH= scriptpath=

  { echo '
echo foo.do
type lib_load || echo no lib load
echo scriptpath=$scriptpath SCRIPTPATH=$SCRIPTPATH
echo sys_lib_loaded=$sys_lib_loaded
echo package_lib_loaded=$package_lib_loaded
scriptpath=$BATS_CWD . $BATS_CWD/util.sh
export scriptpath
' ;
  } > foo.do

  { echo '
redo-ifchange foo
echo bar.do
type lib_load || echo no lib load
echo scriptpath=$scriptpath SCRIPTPATH=$SCRIPTPATH
echo sys_lib_loaded=$sys_lib_loaded
echo package_lib_loaded=$package_lib_loaded
scriptpath=$BATS_CWD . $BATS_CWD/util.sh
' ;
  } > bar.do

  redo bar

  # Neither of the targets found an scriptpath, even not after exporting it at the
  # end of foo
  grep -q 'scriptpath= SCRIPTPATH=$' foo
  grep -q 'scriptpath= SCRIPTPATH=$' bar

  # Neither of the targets had access to lib_load() initially
  grep -q '^no lib load$' foo
  grep -q '^no lib load$' bar

  rm foo foo.do bar bar.do
}
