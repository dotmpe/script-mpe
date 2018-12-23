#!/bin/ash
# See .travis.yml


export_stage script && announce_stage

failed=/tmp/htd-build-test-$(get_uuid).failed
. ./tools/ci/parts/build.sh

export script_end_ts="$($gdate +"%s.%N")"
# XXX: old shippable-CI hack
test "$SHIPPABLE" = true || test ! -e "$failed"

announce "Done"
#announce "All OK"

#
