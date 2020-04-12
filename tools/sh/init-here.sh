#!/usr/bin/env bash

set -euo pipefail

# Alternative to init.sh (for project root dir), XXX: setup for new script subenv
# for this project. To get around the Sh no-source-arg limitation, instead of
# env keys instead this evaluates $@ after taking args. And it is still able to
# use $0 to get this scripts pathname and $PWD to add other dir.

# <script_util>/init-here.sh [SCRIPTPATH] [boot-script] [boot-libs] "$@"

test -n "${CWD-}" || CWD="$PWD"

# provisionary logger setup
test -n "${LOG:-}" -a -x "${LOG:-}" -o \
  "$(type -t "${LOG:-}" 2>/dev/null )" = "function" &&
  LOG_ENV=1 INIT_LOG=$LOG || LOG_ENV=0 INIT_LOG=$CWD/tools/sh/log.sh
# Sh-Sync: tools/sh/parts/env-init-log.sh

test -n "${sh_src_base-}" || sh_src_base=/src/sh/lib

test -n "${1-}" && scriptpath=$1 || scriptpath=$(pwd -P)
#test -n "$scriptpath" || scriptpath="$(dirname "$(dirname "$(dirname -- "$0")")" )" # No-Sync
test -n "${scriptname-}" || scriptname="$(basename -- "$0")" # No-Sync
base=$scriptname

test -n "${U_S-}" -a -d "${U_S-}" || . $scriptpath/tools/sh/parts/env-0-u_s.sh
test -n "${U_S-}" -a -d "${U_S-}" || $LOG "error" "" "Missing U-s" "$U_S" 1

# Must be started from script-package, or provide SCRIPTPATH
test -n "${SCRIPTPATH-}" || . $scriptpath/tools/sh/parts/env-scriptpath-deps.sh

test -n "${sh_tools-}" || sh_tools="$U_S/tools/sh"
type sh_include >/dev/null 2>&1 || {
  . "$sh_tools/parts/include.sh" || return
}


# Now include module with `lib_load`
test -z "${DEBUG-}" || echo . $U_S$sh_src_base/lib.lib.sh >&2
{
  . $U_S$sh_src_base/lib.lib.sh || return
  lib_lib_load && lib_lib_loaded=0 || return
  lib_lib_init
} ||
  $INIT_LOG "error" "$scriptname:init.sh" "Failed at lib.lib $?" "" 1

# And conclude with logger setup but possibly do other script-util bootstraps.

test -n "$3" && init_sh_libs="$3" || init_sh_libs=sys\ os\ str\ script

test "$init_sh_libs" = "0" || {
  lib_load $init_sh_libs && lib_init

  test -n "$2" && init_sh_boot="$2" || init_sh_boot=stderr-console-logger
  script_init "$init_sh_boot" || $status $?
}

# XXX: test -n "$LOG_ENV" && unset LOG_ENV INIT_LOG || unset LOG_ENV INIT_LOG LOG

shift 3

eval "$@"

# Sync: U-S:tools/sh/init-here.sh
# Id: script-mpe/0.0.4-dev tools/sh/init-here.sh
