#!/usr/bin/env bash

# The Us-bin redo script

# Created: 2016-09-16

# Remove settings from file so they don't affect all builds.


# XXX: keep in .build-static.sh for now for projects that don't depend on @dev
# . ./.build-static.sh >&2 || exit $?
CWD=${REDO_STARTDIR:?}
BUILD_TOOL=redo
BUILD_ID=$REDO_RUNID
BUILD_STARTDIR=$CWD
BUILD_BASE=${REDO_BASE:?}
BUILD_PWD="${CWD:${#BUILD_BASE}}"
test -z "$BUILD_PWD" || BUILD_PWD=${BUILD_PWD:1}
BUILD_SCRIPT=${BUILD_PWD}${BUILD_PWD:+/}default.do
test -z "$BUILD_PWD" && BUILD_PATH=$CWD || BUILD_PATH=$CWD:$BUILD_BASE
BUILD_PATH=$BUILD_PATH:${U_S:?}

for BUILD_SEED in \
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
