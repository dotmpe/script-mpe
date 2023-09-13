#!/usr/bin/env bash
set -euo pipefail

: "${BATS_TEST_DESCRIPTION:=}"

. ~/bin/script-mpe.lib.sh
. ~/project/user-conf/test/helper.bash
for suite in "$@"
do
  . "$suite"
done
