#!/usr/bin/env bash

# Env without any pre-requisites.


: "${INIT_LOG:="$CWD/tools/sh/log.sh"}"


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

: "${CWD:="$PWD"}"
: "${DEBUG:=}"
: "${BASHOPTS:=}"
: "${OUT:="echo"}"
: "${TAB_C:="	"}"
#: "${TAB_C:="`printf '\t'`"}"
#: "${NL_C:="`printf '\r\n'`"}"


export scriptname=${scriptname:-"`basename "$0"`"}
export uname=${uname:-"`uname -s | tr '[:upper:]' '[:lower:]'`"}


# Set GNU 'aliases' to try to build on Darwin/BSD

case "$uname" in
  darwin )
      export gdate=${gdate:-"gdate"}
      export ggrep=${ggrep:-"ggrep"}
      export gsed=${gsed:-"gsed"}
      export gawk=${gawk:-"gawk"}
      export gstat=${gstat:-"gstat"}
      export guniq=${guniq:-"guniq"}
    ;;
  linux )
      export gdate=${gdate:-"date"}
      export ggrep=${ggrep:-"grep"}
      export gsed=${gsed:-"sed"}
      export gawk=${gawk:-"awk"}
      export gstat=${gstat:-"stat"}
      export guniq=${guniq:-"uniq"}
    ;;
  * ) $LOG "warn" "" "uname" "$uname" ;;
esac


: "${script_util:="$CWD/tools/sh"}"
: "${ci_util:="$CWD/tools/ci"}"
export script_util ci_util
