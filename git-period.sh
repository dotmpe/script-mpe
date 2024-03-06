# Very simple helper to provide stattab line based on filepath(s)
# Usage:
#   git-period.sh [--follow] [<paths...>]

test $# -gt 0 || set -- $PWD

end=$(git log --date=short --format="%cd" -n 1 "$@")
read -r start <<< $(git log --date=short --format="%cd" --reverse "$@")

# Print dates including last argument at output
echo "- $start $end ${*:$#}"
