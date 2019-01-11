#!/usr/bin/env bash
# See .travis.yml

set -u
export_stage script && announce_stage

./sh-main spec
#./sh-main project

# XXX: restore or move to other earlier stage
#ci_announce 'Checking project tooling, host env, 3rd party setup...'
#. ./tools/ci/parts/baseline.sh

bash ./sh tooling_baseline
bash ./sh project_baseline


# XXX: see +script-mpe, cleanup
failed=/tmp/htd-build-test-$(get_uuid).failed
. "./tools/ci/parts/build.sh"

# XXX: old shippable-CI hack
test "$SHIPPABLE" = true || test ! -e "$failed"

close_stage && ci_announce "Done"
set +u
