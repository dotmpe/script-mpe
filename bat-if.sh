#!/usr/bin/env bash

## Helper to start pager based on LINES or UC_OUTPUT_LINES


set -euo pipefail

# This is not set in non-interactive script ctx
true "${LINES:=$(tput lines)}"

args=${@:-/dev/stdin}
#echo "cat-if pager reading (from) '$args'" >&2
data=$(<"$args")
lines=$(echo "$data" | wc -l)
# Set either USER_LINES or UC_OUTPUT_LINES in profile to page on more or less
# lines
maxlines=${USER_LINES:-${UC_OUTPUT_LINES:-${LINES:?}}}
#echo "cat-if pager read $lines lines, max output is $maxlines" >&2

test $maxlines -le $lines && {
  bat_opts=--paging=always\ --style=numbers
} || {
  bat_opts=--paging=never\ --style=grid,header,numbers\ --file-name="$args"
}

# Careful: if PAGER is set to this script, IF_PAGER must be set as well

# Bats will use $PAGER setting as well, so set it to less...
test -z "${IF_PAGER:-}" &&
    true ||
    PAGER=less

echo "$data" | exec ${IF_PAGER:-${PAGER:?}} $bat_opts
#
