#!/usr/bin/env bash

# The Us-bin redo script

# Created: 2016-09-16

# Remove settings from file so they don't affect all builds.

# XXX: keep in .build-static.sh for now for projects that don't depend on @dev
for BUILD_SEED in \
  ${PWD:?}/.build-static.sh \
  ${REDO_STARTDIR:?}/.env.sh \
  ${REDO_STARTDIR:?}/.build-env.sh
do
  test ! -e "${BUILD_SEED:?}" && continue
  source "${BUILD_SEED:?}" >&2 || exit $?
done

# Start standardized redo for build.lib
. "${UCONF:?}/tools/redo/local.do"

# Sync: US
# Id: Us-bin:default.do                                     ex:ft=bash:
