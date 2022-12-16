#
. ${US_BIN:=${HOME:?}/bin}/_lib.sh


test_q ()
{
  sh_null "$@"
}

sh_null ()
{
  "$@" >/dev/null
}

# Run command X times. Ignore status. Does nothing for IO, see
# Either Cmd or function test_<name> is executed <Iter-count> times, remaining
# argv is passed to invocation for both cases.
run_all () # ~ <Iter-count> [ <Prefix-prefix> <Test-name> | -- ] [ <Cmd <...>> ]
{
  local iter=${1:?} cmd=${2:?} handler
  shift 2 || return
  handler=$(test "$cmd" = "--" && echo false || echo true)
  $handler && {
      cmd=${cmd}${1:-}
      shift
      $LOG notice "Starting" "$cmd $*"
    } || {
      $LOG notice "Starting" "$*"
    }
  while test "$iter" -gt "0"
  do
    ! $handler && {
      "$@" || true
    } || {
      ${cmd} "$@" || true
    }
    iter=$(( iter - 1 ))
  done
}

# Mostly like run-all, except before starting any test, get data at <Prefix>_data,
# <cmd ...> or from current stdin and save as string var
run_all_with_input () # ~ [ <Data-Prefix> | <Data-cmd> -- | -- ] \
  # <Iter-count> [ <Test-Prefix> <Test-name> | -- ] [ <Cmd <...>> ]
{
  local data

  test "${1:?}" = '--' && {
    read -r data
  } || {
    test_q declare -F "${1:?}data" && {
      data=$(${1}data)
    } || {
      declare -ga data_cmd=()
      while test "$1" != '--'
      do
        data_cmd+=( "$1" )
        shift
      done
      data=$("${data_cmd[@]}") || return
    }
    shift
  }

  local iter=${1:?} cmd=${2:?} handler
  shift 2 || return
  handler=$(test "$cmd" = "--" && echo false || echo true)
  $handler && {
      cmd=${cmd}${1:-}
      shift
      $LOG notice "Starting" "$cmd $*"
    } || {
      $LOG notice "Starting" "$*"
    }
  while test "$iter" -gt "0"
  do
    echo "$data" | {
      ! $handler && {
        "$@" || true
      } || {
        ${cmd} "$@" || true
      }
    }
    iter=$(( iter - 1 ))
  done
}
# Derive: run_all


## Test helpers

# run-all but set prefix to 'test_'
run_test () # ~ <Iter-count> [ <Test-name> | -- ] [ <Cmd <...>> ]
{
  local iter=${1:?}
  shift
  run_all $iter test_ "$@"
}

# Like run-all but the argv has to be prefixed with data spec for
# run-all-with-input. This is just a silenced invocation of run-test-io-V.
run_test_io () # ~ ( <Data-Prefix> | <Data-cmd> -- | -- ) \
  # <Iter-count> [ <Test-name> | -- ] [ <Cmd <...>> ]
{
  sh_null run_test_io_V "$@"
}

# Like run-all but the argv has to be prefixed with data spec for
# run-all-with-input.
run_test_io_V () # ~ ( <Data-Prefix> | <Data-cmd> -- | -- ) \
  # <Iter-count> [ <Test-name> | -- ] [ <Cmd <...>> ]
{
  local dpref=${1:-test_}
  shift
  run_all_with_input $dpref "$@"
}

# ID:
