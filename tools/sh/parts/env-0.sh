#!/bin/ash

: "${INIT_LOG:="$PWD/tools/sh/log.sh"}"

# Pre-checks

test -z "$BASH_ENV" || {
  $INIT_LOG "warn" "" "Bash-Env specified" "$BASH_ENV"
  test -f "$BASH_ENV" || $INIT_LOG "warn" "" "No such Bash-Env script" "$BASH_ENV"
}

test -z "$CWD" || {
  test "$CWD" = "$PWD" || {
    $INIT_LOG "error" "" "CWD =/= PWD" "$CWD"
    CWD=
  }
}


# Start env

# XXX: where-to
#set -o pipefail
#set -o errexit
#set -o nounset

: "${CWD:="$PWD"}"
: "${uname:="`uname -s`"}"
# XXX: : "${scriptpath:=$CWD$sh_src_base}"
: "${script_util:="$CWD/tools/sh"}"
: "${ci_util:="$CWD/tools/ci"}"
export script_util ci_util
