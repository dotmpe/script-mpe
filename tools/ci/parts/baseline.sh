#!/bin/ash
# Part of ci:script, see also sh-baseline

# Check project tooling and host env, 3rd party deps

./.git/hooks/pre-commit || print_red "ci:script" git:hook:ERR:$?

. ./tools/ci/parts/bl-sh-tooling.sh

. ./tools/ci/parts/bl-bats-suite.sh
