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

test ${USER_LINES:-${UC_OUTPUT_LINES:-${LINES:?}}} -le $lines && {
  PAGER=cat
} || {
  PAGER=less
}
echo "$data" | exec $PAGER
#
