#!/usr/bin/env bash

## Helper to start pager based on LINES or UC_OUTPUT_LINES

# XXX: something to use may be if no batcat install is available.
# see bat-if.sh

set -euo pipefail

# This is not set in non-interactive script ctx
true "${LINES:=$(tput lines)}"

#echo "cat-if pager reading '$*' or stdin" >&2
data=$(<"${@:-/dev/stdin}")
lines=$(echo "$data" | wc -l)
#echo "cat-if pager read $lines lines" >&2
maxlines=${USER_LINES:-${UC_OUTPUT_LINES:-${LINES:?}}}

test $maxlines -le $lines && {
  test ${v:-${verbosity:-3}} -lt 6 ||
      echo "cat-if read $lines lines, max inline output is $maxlines" >&2
  PAGER=less
} || {
  PAGER=cat
}
echo "$data" | exec $PAGER
#
