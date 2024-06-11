# Very simple helper to provide stattab line based on filepath(s)
# Usage:
#   git-period.sh [--follow] [<paths...>]

test $# -gt 0 || set -- $PWD
for path
do
  end=$(git log --date=short --format="%cd" -n 1 "${path:?}") &&
  read -r start <<< $(git log --date=short --format="%cd" --reverse "$path")
  echo "- $start $end $path"
done
