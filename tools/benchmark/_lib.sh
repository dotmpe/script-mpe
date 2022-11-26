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

#REDO_RUNID= source ./default.do
sh_mode ()
{
  test $# -eq 0 && {
    # XXX: sh-mode summary
    echo "$0: sh-mode: $-" >&2
    trap >&2
  } || {
    while test $# -gt 0
    do
      case "${1:?}" in
          ( test|build|ci )
                set -CET &&
                trap "test_error_handler" ERR
              ;;
          ( dev|debug )
                set -hET &&
                shopt -s extdebug
              ;;
          ( strict ) set -euo pipefail ;;
          ( * ) stderr_ "! $0: sh-mode: Unknown mode '$1'" 1 || return ;;
      esac
      shift
    done
  }
}
# Copy: sh-mode

test_error_handler ()
{
  local r=$? lastarg=$_
  $LOG error ":on-error" "In test" "E$r:$lastarg:$0:$*"
  exit $r
}
# Derive: error-handler

# ID:
