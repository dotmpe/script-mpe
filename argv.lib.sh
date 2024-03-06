
## Helpers

# Read sequence of arguments and flags until end '--' or long-option.
argv_hseq () # ~ <Arr> <Argv...> [--* ...]
{
  argv_more=argv_opt_more argv_seq "$@"
}

argv_is_seq () # ~ <Argv...> # True if immediate item is seq. end '--'
{
  [[ "${1-}" = "--" ]]
}

argv_opt_more () # ~ <Argv...> # True if more arguments (non-long-option or seq end)
{
  [[ $# -gt 0 && "${1:0:2}" != "--" ]]
}

argv_oseq () # ~ <offset> <arr> <args...> [--* ...]
{
  declare o=${1:?} &&
  declare -n arr=${2:?} &&
  arr+=( "${@:3:$o}" ) &&
  o=$(( 3 + o )) &&
  ${argv_seq:-argv_seq} "$2" "${@:$o}"
}

argv_scan () # ~ <var> <test> <args...>
{
  declare -n r=${1:?}
  declare i test=${2:?}
  shift 2
  for (( i=1; i<$#; i++ ))
  do
    $test "${!i}" || break
  done
  r=$i
}

# Read sequence of arguments until '--' (sequence end)
argv_seq () # ~ <Arr> <Argv... [-*]> <...>
{
  declare si=2
  declare -n arr=${1:?}
  while ${argv_more:-argv_seq_more} "${@:$si}"
  do
    arr+=( "${!si}" )
    si=$(( si + 1 ))
  done
}

argv_seq_more () # ~ <Argv...> # True if more for current sequence is available.
{
  [[ $# -gt 0 && "${1-}" != "--" ]]
}

#
