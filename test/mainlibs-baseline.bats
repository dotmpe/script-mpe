#!/usr/bin/env bats

load init
base="baseline-4:mainlibs"

setup()
{
  case "$BATS_TEST_NUMBER" in

    2|4 ) init 1 0 0 0 ;;
    6 ) init ;;

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

    * ) init 0 ;;
  esac
}


@test "$base: test framework" {

  test -n "$base" -a -n "$uname"
  echo "testpath: $testpath"
  test -n "$testpath" -a -d "$testpath"
  echo "SHT_PWD: $SHT_PWD"
  test -n "$SHT_PWD" -a -d "$SHT_PWD"

  test -s "$testpath/helper/extra.bash"
  test -s "$testpath/helper/stdtest.bash"
  test -s "$testpath/helper/assert.bash"

  echo "BATS_LIB_PATH: $BATS_LIB_PATH"
  test -n "$BATS_LIB_PATH"

  # Better tested utils shipped to avoid using baselibs during test
  run load extra
  test $status -eq 0 -a -z "${lines[*]}" || {
      printf "Status: $status\nLines:\n${lines[@]}"
      false
    }

  load extra

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

  echo "lib: $lib_lib_loaded"
  test -n "$lib_lib_loaded"

  load extra stdtest

  for _i in ${BATS_LIB_PATH//:/ }
  do
    test -d "$_i" || fail "existing dir expected '$_i'"
  done

  load assert

  echo "scriptpath: $scriptpath"
  assert test -n "$scriptpath"
  echo "script_util: $script_util"
  assert test -n "$script_util"
  assert test -n "$SCRIPTPATH"
  assert test -d "$scriptpath"
  assert test -e "$scriptpath/lib.lib.sh"
  assert test -d "$script_util"
  assert test -e "$script_util/init.sh"
  assert test -e "$script_util/boot/null.sh"
}

@test "$base: init.sh / base shell" {

  run $SHELL -c "$script_util/init.sh"

  load stdtest

  run bash -c "$(cat <<EOM

U_S=$BATS_CWD . $BATS_CWD/tools/sh/init.sh &&
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

  test -z "$os_lib_loaded" -a \
    -z "$str_lib_loaded" -a \
    -z "$sys_lib_loaded"
  lib_load sys
  echo "sys: $sys_lib_loaded"
  echo "os: $sys_lib_loaded"
  echo "str: $sys_lib_loaded"
  lib_load os str
  test -n "$os_lib_loaded" -a -n "$str_lib_loaded"

  load extra stdtest

  for lib in sys os str shell logger logger-std logger-theme
  do
    run lib_load $lib
    test_ok_empty || stdfail $lib
  done
}

@test "$base: test init.bash 0" {

  type test_env_init >/dev/null
  type hostname_init >/dev/null
  type init >/dev/null
  env | grep -q '^base=' && false || true
  env | grep -q '^hostnameid=' && false || true
  env | grep -q '^ENV_NAME='

  type trueish >/dev/null && false || true
  type fnmatch >/dev/null && false || true
  type tmpd >/dev/null && false || true
  type tmpf >/dev/null && false || true
  type get_uuid >/dev/null && false || true
}

@test "$base: test init.bash" {

  { func_exists basedir &&
    test $os_lib_loaded -eq 1
  } || false "Error with os.lib"

  { func_exists mkid &&
    test $str_lib_loaded -eq 1
  } || false "Error with str.lib"

  { func_exists fnmatch &&
    test $sys_lib_loaded -eq 1
  } || false "Error with sys.lib"

  return

# TODO: revise logger setup
#  func_exists note
#  func_exists warn
#  func_exists error

  {
    func_exists debug &&
    func_exists std_info &&
    func_exists note &&
    func_exists warn &&
    func_exists error
  } || false "Error with std.lib"
}
