#!/usr/bin/env bash

# Env without any pre-requisites.


: "${INIT_LOG:="$U_S/tools/sh/log.sh"}"


# Env pre-checks

test -z "${BASH_ENV:-}" || {
  $INIT_LOG "warn" "" "Bash-Env specified" "$BASH_ENV"
  test -f "$BASH_ENV" || $INIT_LOG "warn" "" "No such Bash-Env script" "$BASH_ENV"
}

test -z "${CWD:-}" || {
  test "$CWD" = "$PWD" || {
    $INIT_LOG "error" "" "CWD =/= PWD" "$CWD"
    CWD=
  }
}

# Start 0. env

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

# Sync: U-S:
