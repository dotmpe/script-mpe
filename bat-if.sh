#!/usr/bin/env bash

## Helper to start pager based on LINES or UC_OUTPUT_LINES


set -euo pipefail

# This is not set in non-interactive script ctx
true "${LINES:=$(tput lines)}"

args=${@:-/dev/stdin}
#echo "bat-if pager reading (from) '$args'" >&2
data=$(<"$args")
lines=$(echo "$data" | wc -l)
# Set either USER_LINES or UC_OUTPUT_LINES in profile to page on more or less
# lines
maxlines=${USER_LINES:-${UC_OUTPUT_LINES:-${LINES:?}}}

test $maxlines -le $lines && {
  test ${v:-${verbosity:-3}} -lt 6 ||
      echo "bat-if read $lines lines, max inline output is $maxlines" >&2
  bat_opts=--paging=always\ --style=rule,numbers
} || {
  bat_opts=--paging=never\ --style=grid,numbers
}

test "$args" = /dev/stdin || bat_opts=$bat_opts,header\ --file-name="$args"


# Careful: if PAGER is set to this script, IF_PAGER must be set as well

# Bats will use $PAGER setting as well, so set it to less...
test -z "${IF_PAGER:-}" || {
    export PAGER=less
}

echo "$data" | ${IF_PAGER:-${PAGER:?}} $bat_opts
#
