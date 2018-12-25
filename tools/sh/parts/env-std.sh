#!/bin/ash

: "${LOG:="$CWD/tools/sh/log.sh"}"
: "${CS:="dark"}"
: "${DEBUG:=}"
: "${verbosity:=}"
test -z "${v-}" || verbosity=$v
export verbosity DEBUG LOG CS
#
