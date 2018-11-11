#!/bin/sh
fail() { echo "failed: $block: $1">&2; export test=1; }

block="str.lib mkid"
test -z "$c" || fail "c: $c"
test -z "$s" || fail "s: $s"
test -z "$upper" || fail "upper: $upper"

exit $test
