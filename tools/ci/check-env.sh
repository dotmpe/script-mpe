#!/bin/sh

set -e

# Initialize env
. $scriptdir/tools/sh/init.sh
. ./tools/sh/env.sh

note "Checking build parameterisation.."

case "$TEST_SHELL" in
  sh|dash|posh|bash ) ;;
  * ) error "Missing/Unknown TEST-SHELL '$TEST_SHELL'" ;;
esac

