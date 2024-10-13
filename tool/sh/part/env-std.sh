#!/usr/bin/env bash

: "${LOG:="$CWD/tool/sh/log.sh"}"
: "${CS:="dark"}"
: "${DEBUG:=}"
test -z "${DEBUG-}" || shopt -s extdebug
: "${verbosity:=}"
test -z "${v-}" || verbosity=$v
# Sync: U-S:
