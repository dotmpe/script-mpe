
# XXX: move these to parts files, see bash-fun profile part

at_ () # ~ <base> [<base..>]
{
  while test 0 -lt $#
  do
    ctxv=${1//[^A-Za-z0-9_]/_}ctx
    test -n "${!_:-}" &&
    std_quiet declare -F $_ && {
      set -- $_ "${@:2}"
      break
    }

    uc_script_load "${1:?}" || return
    ! std_quiet declare -F at_${1//[^A-Za-z0-9_]/_} || {
      set -- $_ "${@:2}"
      break
    }
    shift
  done
  test 0 -eq $# && return
  "$@"
}

if_ok ()
{
  return
}

std_noerr ()
{
  "$@" 2>/dev/null
}

std_noout ()
{
  "$@" >/dev/null
}

std_quiet ()
{
  "$@" >/dev/null 2>&1
}

#
