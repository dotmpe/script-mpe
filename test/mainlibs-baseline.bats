#!/usr/bin/env bats

load init
base="baseline-4:mainlibs"

setup()
{
# FIXME: test/init.bash:init interferes with Bats normal and tap output somehow
  case "$BATS_TEST_DESCRIPTION" in
    
    *" test framework: vanilla"* ) ;;
    *" test framework: init 0: "* ) init 0 ;;
    *" test framework: init 1 0: "* ) init 1 0 ;;
    *" test framework: init 1: "* ) init 1 ;;

    *" base shell" )            ;;

    *" test framework: helpers"* | \
    *" base env" | \
    *" base libs" \
      ) init 1 0 0 0 ;;

#    # Partial init
#    *"init.bash 0"* ) init "" 0;;
#
#    # Defaults
#    *"init.bash"* ) init ;;
#
#    # Init only, don't source any lib including lib.lib
#    *"base shell"* ) init 0 ;;

#    # Init only, and setup lib.lib
#    * ) init "" 0 0 0 ;;

#    * ) init 0 ;;
  esac
}


@test "$base: test framework: vanilla shell, no-init" {
  test -z "$uname"
  test -z "$testpath"
  test -z "$SHT_PWD"
  test -z "$BATS_LIB_PATH"
  type test_env_init >/dev/null
  type init >/dev/null
  # look for exported env
  env | grep -q '^base=' && false || true
  env | grep -q '^hostnameid=' && false || true
  type trueish >/dev/null && false || true
  type fnmatch >/dev/null && false || true
  type tmpd >/dev/null && false || true
  type tmpf >/dev/null && false || true
  type get_uuid >/dev/null && false || true
}

@test "$base: test framework: init 0: set only load() and BATS_LIB_PATH" {
  test -n "$base"
  test -z "$uname"
  test -z "$testpath"
  test -z "$SHT_PWD"
  test -n "$BATS_LIB_PATH"
  type test_env_init >/dev/null
  type init >/dev/null
  type trueish >/dev/null && false || true
  type fnmatch >/dev/null && false || true
  type tmpd >/dev/null && false || true
  type tmpf >/dev/null && false || true
  type get_uuid >/dev/null && false || true
}

@test "$base: test framework: init 1 0: also testenv and minimal lib_load" {

  { type lib_load >/dev/null 2>&1 && test $lib_lib_loaded -eq 0
  } || false "Error with lib.lib"
  diag "Libs loaded: ${lib_loaded-}"
}

@test "$base: test framework: init 1: preload libs" {
  diag "SCRIPTPATH: $SCRIPTPATH"
  diag "Libs loaded: $lib_loaded"

  { type basedir >/dev/null 2>&1 && test $os_lib_loaded -eq 0
  } || false "Error with os.lib"

  { type mkid >/dev/null 2>&1 && test $str_lib_loaded -eq 0
  } || false "Error with str.lib"

  { func_exists fnmatch && test $sys_lib_loaded -eq 0
  } || false "Error with sys.lib"
}

@test "$base: test framework: init 1 0: can load std" {
  lib_load sys std
  {
    func_exists debug &&
    func_exists std_info &&
    func_exists note &&
    func_exists warn &&
    func_exists error
  } || false "Error with std.lib"
}

@test "$base: test framework: helpers: extra, stdtest and assert" {

  test -n "$base" -a -n "$uname"
  diag "testpath: $testpath"
  test -n "$testpath" -a -d "$testpath"
  diag "SHT_PWD: $SHT_PWD"
  test -n "$SHT_PWD" -a -d "$SHT_PWD"

  test -s "$testpath/helper/extra.bash"
  test -s "$testpath/helper/stdtest.bash"
  test -s "$testpath/assert.bash"

  diag "BATS_LIB_PATH: $BATS_LIB_PATH"
  test -n "$BATS_LIB_PATH"

  # Better tested utils shipped to avoid using baselibs during test
  run load helper/extra
  test $status -eq 0 -a -z "${lines[*]}" || {
      printf "Status: $status\nLines:\n${lines[@]}"
      false
    }

  load helper/extra

  # Bats test helpers
  run load stdtest
  test $status -eq 0
  test -z "${lines[*]}"

  load stdtest

  # More test helpers
  run load assert
  test_ok_empty || stdfail assert
}

@test "$base: base env" {

  load extra stdtest
  test -n "$lib_lib_loaded"

  for _i in ${BATS_LIB_PATH//:/ }
  do
    test -d "$_i" || fail "existing dir expected '$_i'"
  done

  load assert

  diag "sh_tools: $sh_tools"
  assert test -n "$sh_tools"
  assert test -n "$SCRIPTPATH"
  assert test -d "$U_S"
  assert test -e "$U_S/src/sh/lib/lib.lib.sh"
  assert test -d "$sh_tools"
  assert test -e "$sh_tools/init.sh"
  assert test -e "$sh_tools/boot/null.sh"
}

@test "$base: init.sh : base shell" {

  skip "FIXME: $main_inc"
  run $SHELL -c "$sh_tools/init.sh"

  load stdtest

  run bash -c "$(cat <<EOM

. $BATS_CWD/tools/sh/init.sh &&
source '$main_inc' &&
try_exec_func mytest_function

EOM
    )"
  diag "Output: ${lines[0]}"
  {
    test $status -eq 0 && fnmatch "mytest" "${lines[*]}"
  } || stdfail 3.
}

@test "$base: base libs" {

  test -z "$os_lib_loaded"
  lib_load sys
  echo "sys: $sys_lib_loaded"
  echo "os: $sys_lib_loaded"
  lib_load os str
  test -n "$os_lib_loaded" -a -n "$str_lib_loaded"

  load extra stdtest

  for lib in shell logger logger-std logger-theme
  do
    run lib_load $lib
    test_ok_empty || stdfail $lib
  done
}
