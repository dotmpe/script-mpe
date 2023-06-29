
. ${US_BIN:=${HOME:?}/bin}/script-mpe.lib.sh

# See bm-baseline for current state of benchmarking goals

# Should want to generate scripts instead, execute those on a clean noiseless
# environment and report/process the results. But until then this generates
# actual numbers to compare some shell idioms for different use cases.

#fun_copy test_q std_quiet
# etc.

test_q ()
{
  sh_nout "$@"
}

sh_nout ()
{
  "$@" >/dev/null
}

sh_nerr ()
{
  "$@" 2>/dev/null
}

sh_noe ()
{
  "$@" >/dev/null 2>&1
}


# Run command X times. Ignore status. Does nothing for IO, see
# Either Cmd or function test_<name> is executed <Iter-count> times, remaining
# argv is passed to invocation for both cases.
run_all () # ~ <Iter-count> [ <Prefix-prefix> <Test-name> | -- ] [ <Cmd <...>> ]
{
  local iter=${1:?} cmd=${2:?} handler run_stat=${run_stat:-true}
  shift 2 || return
  handler=$(test "$cmd" = "--" && echo false || echo true)
  $handler && {
      cmd=${cmd}${1:-}
      shift
      ${quiet:-false} ||
          $LOG notice "run-all Starting $iter" "$cmd $*"
    } || {
      ${quiet:-false} ||
          $LOG notice "run-all Starting $iter" "$*"
    }
  while test 0 -lt $iter
  do
    ! $handler && {
      "$@" || $run_stat
    } || {
      ${cmd} "$@" || $run_stat
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
  test "${1:-}" = "--" || set -- test_ "$@"
  run_all $iter "$@"
}

run_test_q () # ~ <Iter-count> [ <Test-name> | -- ] [ <Cmd <...>> ]
{
  sh_nout run_test "$@"
}

# Like run-all but the argv has to be prefixed with data spec for
# run-all-with-input. This is just a silenced invocation of run-test-io-V.
run_test_io () # ~ ( <Data-Prefix> | <Data-cmd> -- | -- ) \
  # <Iter-count> [ <Test-name> | -- ] [ <Cmd <...>> ]
{
  sh_nout run_test_io_V "$@"
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

funbody ()
{
  declare -f "${1:?}" | tail -n +3 | head -n -1 | sed 's/^\s*//'
  #typeset -f "${1:?}" | sed 's/^\(\('"$1"' *() *\)\|\({ *\)\|}\)$//' | grep -v '^ *$'
}

time_gnu_parse_seconds ()
{
  local min sec
  read -r _ min sec <<< "${1/m/ }"
  : "${sec%s}"
  echo "$(( 60 * min + ${_/.*} )).${_/*.}"
}

run_time ()
{
  ${quiet:-true} ||
      $LOG notice :run-time "Starting timed run" "$*"
  mapfile -t time_lines <<< "$( (time "$@" 2>&3 ) 3>&2 2>&1 )"
  time_real=$(time_gnu_parse_seconds "${time_lines[1]}") &&
  time_user=$(time_gnu_parse_seconds "${time_lines[2]}") &&
  time_sys=$(time_gnu_parse_seconds "${time_lines[3]}")
}

sample_time ()
{
  local samples=${1:?} real=0 user=0 sys=0
  shift
  for sample in $(seq 1 $samples)
  do
    run_time "$@" || return
    ${quiet:-true} ||
        $LOG info :$sample/$samples "sampling runtime" "$time_real:$time_user:$time_sys"
    real=$( echo $real + $time_real | bc -l )
    user=$( echo $user + $time_user | bc -l )
    sys=$( echo $sys + $time_sys | bc -l )
  done
  avg_real=$(echo "$real / $samples" | bc -l)
  avg_user=$(echo "$user / $samples" | bc -l)
  avg_sys=$(echo "$sys / $samples" | bc -l)
}

report_time () # ~ <Header=_> [<Tail...>]
{
  set -- "${1:-$_}" "${*:2}"
  : "${report_time_p:=5}"
  : "real:%.${_}f\tuser:%.${_}f\tsys:%.${_}f"
  #shellcheck disable=SC2059
  : "$(printf "$_" "0$avg_real" "0$avg_user" "0$avg_sys")"
  # XXX: alt report_time format
  #: "$(sed 's/00*\(\\t\|$\)/\1/g' <<< "real:$avg_real\tuser:$avg_user\tsys:$avg_sys" )"
  echo -e "${1:-$_}\t$_${2:+\t}${2// /$'\t'}"
}

test_baseline () # ~ <Samples> <Runs> <Test-command-line...>
{
  local samples=${1:?} iter=${2:?}
  shift 2
  test $# -gt 0 || set -- true
  sample_time $samples run_test $iter -- "$@"
}

# ID:
