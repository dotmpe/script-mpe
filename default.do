#!/usr/bin/env bash

# The HtDocs redo script

# Created: 2016-09-16

# Remove settings from file so they don't affect very build.

for BUILD_SEED in \
  ${REDO_STARTDIR:?}/.env.sh \
  ${REDO_STARTDIR:?}/.build-env.sh
do
  test ! -e "${BUILD_SEED:?}" && continue
  source "${BUILD_SEED:?}" >&2 || exit $?
done

# Start standardized redo for build.lib
. "${UCONF:?}/tools/redo/local.do"

# Sync: UCONF
# Id: Composure-inc:default.do                                     ex:ft=bash:
