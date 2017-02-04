#!/bin/sh

set -e
test -n "$scriptdir" || 219


test -n "$RUN_INIT" || RUN_INIT=$(
  test -e $scriptdir/tools/sh/init/$1.sh &&
    echo $scriptdir/tools/sh/init/$1.sh ||
    echo $scriptdir/tools/sh/init.sh)

. $RUN_INIT ||
  error "run env init for '$1'" 1


