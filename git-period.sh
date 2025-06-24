# Very simple helper to provide stattab line based on filepath(s)
# Usage:
#   git-period.sh [--follow] [<paths...>]

test $# -gt 0 || set -- $PWD

git_log_dates_cmd=( git log --date=short --format="%cd" )
#git_log_last_date_cmd=( "${git_log_dated_cmd[@]}" -n 1 )
# XXX: --reverse somehow has unpredictable results. so rewriting routine
# to read entire list anyway
#git_log_dates_rev_cmd=( "${git_log_dated_cmd[@]}" --reverse )

cmd_args=()
while [[ $# -gt 0 && "$1" =~ ^- ]]
do
  cmd_args+=( "${1:?}" )
  shift
done
[[ ${#cmd_args[*]} -gt 0 ]] || cmd_args=( --follow )
for path
do
  first= last=
  >&2 echo "> $ ${git_log_dates_cmd[*]} ${cmd_args[*]} ${path:?}..."
  :pass "$("${git_log_dates_cmd[@]}" "${cmd_args[@]}" "$path")" &&
  while read -r date
  do
    [[ ${last:+set} ]] && first=$date || last=$date
  done <<< "${_}" &&
  echo "- $first $last $path" ||
  _ERR "Failed reading log lines"
done
