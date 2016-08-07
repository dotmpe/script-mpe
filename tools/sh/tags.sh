#!/bin/sh
set -e
test -n "$scriptdir" || scriptdir=$(dirname $(dirname $(dirname $0)))

test -n "$verbose" || verbose=true
test -n "$exit" || exit=true


type lib_load 2> /dev/null 1> /dev/null || . $scriptdir/util.sh load-ext

lib_load sys os std str src

out=$(setup_tmpf .out)
trueish "$verbose" && {
  grep -srI XXX * | tee $out
} || {
  grep -srI XXX * > $out || noop
}

cruft=$(count_lines $out)

ret=0
test 0 -eq $cruft || {
  echo Crufty: $cruft counts
  ret=1
}

trueish "$exit" && exit $ret || exit 0

