#!/usr/bin/env bash

set -e

cd tools/ci/vbox

vagrant ssh ubuntu -c whoami || exit 0

vagrant ssh ubuntu -c "cd /vagrant; ./test/*-spec.bats"

