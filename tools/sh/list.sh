#!/bin/sh

set -e
test -n "$scriptdir" || 219


# Init

scriptname=tools:run
. $scriptdir/tools/sh/run.inc.sh "$@"
lib_load build



