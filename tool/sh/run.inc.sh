#!/bin/sh

set -e
test -n "$scriptpath" || 219


test -n "$RUN_INIT" || RUN_INIT=$(
  test -e $scriptpath/tools/sh/init/$1.sh &&
    echo $scriptpath/tools/sh/init/$1.sh ||
    echo $scriptpath/tools/sh/init.sh)

. $RUN_INIT ||
  error "run env init for '$1'" 1

note "Entry"

# Sync:
