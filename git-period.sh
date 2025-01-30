# Very simple helper to provide stattab line based on filepath(s)
# Usage:
#   git-period.sh [--follow] [<paths...>]

test $# -gt 0 || set -- $PWD
: "${gitlog_f:=--follow}"
for path
do
  end=$(git log ${gitlog_f-} --date=short --format="%cd" -n 1 "${path:?}") &&
  read -r start <<< $(git log ${gitlog_f-} --date=short --format="%cd" --reverse "$path")
  echo "- $start $end $path"
done
