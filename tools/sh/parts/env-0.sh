#!/usr/bin/env bash

# Env without any pre-requisites.

# Env pre-checks

test -z "${BASH_ENV:-}" || {
  $INIT_LOG "warn" "" "Bash-Env specified" "$BASH_ENV"
  test -f "$BASH_ENV" || $INIT_LOG "warn" "" "No such Bash-Env script" "$BASH_ENV"
}

# Start 0. env

: "${verbosity:=4}"
: "${SCRIPTPATH:=}"
: "${CWD:="$PWD"}"
: "${DEBUG:=}"
: "${OUT:="echo"}"
: "${PS1:=}"
: "${BASHOPTS:=}" || true
: "${BASH_ENV:=}"
: "${shopts:="$-"}"
: "${SCRIPT_SHELL:="$SHELL"}"
: "${TAB_C:="	"}"
TAB_C="	"
#: "${TAB_C:="`printf '\t'`"}"
#: "${NL_C:="`printf '\r\n'`"}"

test -n "${DEBUG:-}" && : "${keep_going:=false}" || : "${keep_going:=true}"

: "${USER:="$(whoami)"}"
test "$USER" = "treebox" && : "${dckr_pref:="sudo "}"

: "${NS_NAME:="dotmpe"}"
: "${DOCKER_NS:="$NS_NAME"}"
: "${scriptname:="`basename -- "$0"`"}"
: "${LOG:="$CWD/tools/sh/log.sh"}"

$INIT_LOG debug "" "0-env started" ""
# Sync: U-S:
