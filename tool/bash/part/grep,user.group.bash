user_grep_pre=User.Grep

User.Grep.at-basedirs ()
{
  : param '~ <Cmd-arr> <Basedirs...>'
  local -n grep_at_cmdargs=${1:?}
  shift
  [[ ${grep_at_cmdargs[@]:+set} ]] ||
    failerr "$FUNCNAME grep command array required" || return
  local bd
  (($#)) && for bd
  do
    std_quiet pushd "$bd" || return
    "${QUIET:-false}" ||
      >&2 echo "$bd> $ grep [opts] '${grep_at_cmdargs[*]}'"
    >&2 echo grep "${grep_opts[@]}" "${grep_at_cmdargs[@]}" || true
    grep "${grep_opts[@]}" "${grep_at_cmdargs[@]}" || true
    std_quiet popd
  done
}
