
argv_seq () # ~ <Arr> <Argv... [--]> <...>
{
  declare si=2
  declare -n arr=${1:?}
  while argv_has_next "${@:$si}"
  do
    arr+=( "${!si}" )
    si=$(( si + 1 ))
  done
}

argv_has_next () # ~ <Argv...> # True if more for current sequence is available.
{
  test $# -gt 0 -a "${1-}" != "--"
}

argv_is_seq () # ~ <Argv...> # True if immediate item is '--' continuation.
{
  test "${1-}" = "--"
}

#
