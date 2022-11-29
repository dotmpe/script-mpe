#!/usr/bin/env bash

# The HtDocs redo script

# Created: 2016-09-16

# Remove settings from file so they don't affect very build.
. ${REDO_STARTDIR:?}/.env.sh
#. ${REDO_STARTDIR:?}/.build-env.sh

# Start standardized redo for build.lib
. "${UCONF:?}/tools/redo/local.do"

# Sync: UCONF
# Id: Composure-inc:default.do                                     ex:ft=bash:
