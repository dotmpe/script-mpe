#!/usr/bin/env bash

# The HtDocs redo script

# Created: 2016-09-16

true "${redo_opts:="-j4"}"
true "${BUILD_RULES_BUILD:=1}"
true "${ENV:="dev"}"
BUILD_ENV="attributes"
#build-rules rule-params stderr- argv"

# Add dep on this file because it contains some main settings
#test "$1" = :if-lines:./default.do || redo-ifchange :if-lines:./default.do

. "${UCONF:?}/tools/redo/local.do"

# Sync: UCONF
# Id: Composure-inc:default.do                                     ex:ft=bash:
