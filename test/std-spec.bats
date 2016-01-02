#!/usr/bin/env bats

load helper
base=std

init
. $lib/std.sh
. $lib/str.sh

tmd=/tmp/bats-$$/
mkdir -vp $tmd


@test "${lib}/${base} - std_v <n> should return 1 if <n> <= <verbosity>. No output." {

  verbosity=1
  run std_v 1
  test ${status} -eq 0
  test -z "${lines[*]}"
  run std_v 2
  test ${status} -eq 1
  test -z "${lines[*]}"
  run std_v 0
  test ${status} -eq 0
  test -z "${lines[*]}"

  verbosity=6
  run std_v 7
  test ${status} -eq 1
  test -z "${lines[*]}"
  run std_v 1
  test ${status} -eq 0
  test -z "${lines[*]}"
  run std_v 0
  test ${status} -eq 0
  test -z "${lines[*]}"

  verbosity=0
  run std_v 0
  test ${status} -eq 0
  test -z "${lines[*]}"
  run std_v 1
  test ${status} -eq 1
  test -z "${lines[*]}"
}


@test "${lib}/${base} - std_exit <n> should call exit <n> if <n> is an integer number or return 1. No output. " {

  exit(){ echo 'exit '$1' ok'; }

  run std_exit
  test ${status} -eq 1
  test -z "${lines[*]}"

  run std_exit 1
  test ${status} -eq 0
  test "exit 1 ok" = "${lines[*]}"

  run std_exit 0
  test ${status} -eq 0
  test "exit 0 ok" = "${lines[*]}"
}


@test "${lib}/${base} - error should echo at verbosity>=3" {

  verbosity=2
  run info "test"
  test ${status} -eq 0
  test -z "${lines[*]}"

  real_exit=ext
  exit(){ echo 'exit '$1' call'; command exit $1; }

  verbosity=4
  run error "error"
  test ${status} -eq 0
  fnmatch "*error*" "${lines[*]}"

  verbosity=2
  run error "test" 1
  test ${status} -eq 1
  test "exit 1 call" = "${lines[*]}"

  run error "test" 0
  test ${status} -eq 0
  test "exit 0 call" = "${lines[*]}"
}


@test "${lib}/${base} - info should echo at verbosity>=6" {

  verbosity=4
  run info "test" 0
  test ${status} -eq 0
  test -z "${lines[*]}"

  verbosity=5
  run info "test info exit" 3
  test ${status} -eq 3
  test -z "${lines[*]}"

  verbosity=6
  run info "test info exit" 3
  test ${status} -eq 3
  fnmatch "*test info exit*" "${lines[*]}"

  verbosity=6
  run info "test info exit" 0
  test ${status} -eq 0
  fnmatch "*test info exit*" "${lines[*]}"

  verbosity=5
  run info "test" 0
  test ${status} -eq 0
  test -z "${lines[*]}"

  exit(){ echo 'exit '$1' call'; command exit $1; }
  verbosity=6
  run info "test" 0
#  echo ${status} > /tmp/1
#  echo "${lines[*]}" >> /tmp/1
  test ${status} -eq 0
  fnmatch "*exit 0 call" "${lines[*]}"
}

@test "${lib}/${base} - stdio_type works without errors and output" {

  run stdio_type
  test ${status} -eq 0
  test "${lines[*]}" = ""
  run stdio_type 0
  test ${status} -eq 0
  test "${lines[*]}" = ""
  run stdio_type 1
  test ${status} -eq 0
  test "${lines[*]}" = ""
  run stdio_type 2
  test ${status} -eq 0
  test "${lines[*]}" = ""

}

@test "${lib}/${base} - stdio_type detects difference between interactive (terminal) I/O and other and sets stdio_{0,1,2}_type " {

  # std bats IO...
  stdio_type 0
  test "$?" = "0"
  case $(current_test_env) in jenkins )
      test "$stdio_0_type" = "p" ;;
    * )
      test "$stdio_0_type" = "t" ;;
  esac
  stdio_type 1
  test "$?" = "0"
  case $(current_test_env) in travis|jenkins )
      test "$stdio_1_type" = "f" ;;
    * )
      #echo "$stdio_1_type" >>$tmd/stdio_1_type
      test "$stdio_1_type" = "p" ;;
  esac
  stdio_type 2
  test "$?" = "0"
  case $(current_test_env) in * )
      test "$stdio_2_type" = "f" ;;
  esac
}

@test "${lib}/${base} - stdio_type detects interactive (terminal) I/O and other, sets stdio_{0,1,2}_type (cont'd)" {
  #stdio_type 3
  #test "$?" = "0"
  #test "$stdio_3_type" = "p"

  case $(current_test_env) in jenkins )
      skip "TODO a bit more testing with stdio type detection at $(current_test_env)" ;;
    * )
      { echo foo | file /dev/fd/{0,1,2,3} > $tmd/1; }
      echo >>$tmd/1
#  { echo foo | file /dev/fd/0 >> /tmp/1; }
#  { echo foo | stdio_type 0; echo "$stdio_0_type" > /tmp/1; test "$stdio_0_type" = "f"; }
#  { echo foo | stdio_type 1; echo "$stdio_1_type" > /tmp/1; test "$stdio_1_type" = "t"; }
#  { echo foo | stdio_type 2; echo "$stdio_2_type" > /tmp/1; test "$stdio_2_type" = "f"; }
#  test "$stdio_0_type" = "p"
      ;;
  esac

  tmpf
  echo > $tmpf
  stdio_type 0 < $tmpf
  test "$stdio_0_type" = "f"

# FIXME: test on Linux
#  bash -c 'echo foo | stdio_type 0; echo x0=$stdio_0_type > /tmp/1'
#  test "$stdio_0_type" = "p"
}

@test "${lib}/${base} - function should ..." {
  check_skipped_envs || \
    skip "TODO envs $envs: implement lib (test) for env"
  #run function args
  #echo ${status} > /tmp/1
  #echo "${lines[*]}" >> /tmp/1
  #echo "${#lines[@]}" >> /tmp/1
  #test ${status} -eq 0
}

