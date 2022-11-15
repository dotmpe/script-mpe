run_all ()
{
  local pref=${1:?} iter=${2:?} cmd=${3:?}
  shift 3 || return
  while test "$iter" -gt "0"
  do
    test "$cmd" = "--" && {
      "$@" || true
    } || {
      ${pref}${cmd} "$@" || true
    }
    iter=$(( $iter - 1 ))
  done
}

run_test ()
{
  run_all test_ "$@"
}

run_test_q ()
{
  run_test "$@" >/dev/null
}

run_test_io_V () # ~ <Pref> <Iter> <Data> <Cmd>
{
  local pref=${1:?} iter=${2:?} data=${3:?} cmd=${4:?}
  shift 4 || return
  while test "$iter" -gt "0"
  do
    ${data}
    iter=$(( $iter - 1 ))
  done | ${pref}${cmd} "$@"
}

run_test_io ()
{
  run_test_io_V "$@" >/dev/null || true
}
