
## Helpers

argv_is_seq () # ~ <Argv...> # True if immediate item is seq. end '--'
{
  test "${1-}" = "--"
}

# Read sequence of arguments and flags until end '--' or long-option.
argv_hseq () # ~ <Arr> <Argv...> [--* ...]
{
  declare si=2
  declare -n arr=${1:?}
  while argv_more "${@:$si}"
  do
    arr+=( "${!si}" )
    si=$(( si + 1 ))
  done
}

argv_optseq () # ~ <Arr> <Long-opt> <args...> [--* ...]
{
  declare -n arr=${1:?} &&
  test "--" = "${2:0:2}" && arr+=( "$2" ) &&
  argv_hseq "$1" "${@:3}"
}

argv_more () # ~ <Argv...> # True if more arguments (non-long-option or seq end)
{
  test $# -gt 0 && test "${1:0:2}" != "--"
}

# Read sequence of arguments until '--' (sequence end)
argv_seq () # ~ <Arr> <Argv... [-*]> <...>
{
  declare si=2
  declare -n arr=${1:?}
  while argv_seq_more "${@:$si}"
  do
    arr+=( "${!si}" )
    si=$(( si + 1 ))
  done
}

argv_seq_more () # ~ <Argv...> # True if more for current sequence is available.
{
  test $# -gt 0 -a "${1-}" != "--"
}

#
