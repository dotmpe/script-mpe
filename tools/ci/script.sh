#!/bin/ash
# See .travis.yml


export_stage script && announce_stage

# . "./tools/ci/parts/init-build-cache.sh"


failed=/tmp/htd-build-test-$(get_uuid).failed
. "./tools/ci/parts/build.sh"


export script_end_ts="$($gdate +"%s.%N")"

# XXX: old shippable-CI hack
test "$SHIPPABLE" = true || test ! -e "$failed"

close_stage && ci_announce "Done"

. "$ci_util/deinit.sh"
