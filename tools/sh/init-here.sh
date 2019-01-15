#!/bin/sh

# Alternative to init.sh (for project root dir), XXX: setup for new script subenv
# for this project. To get around the Sh no-source-arg limitation, instead of
# env keys instead this evaluates $@ after taking args. And it is still able to
# use $0 to get this scripts pathname and $PWD to add other dir.

# <script_util>/init-here.sh [SCRIPTPATH] [boot-script] [boot-libs] "$@"

# provisionary logger setup
test -n "$LOG" && LOG_ENV=1 || LOG_ENV=
test -n "$LOG" -a -x "$LOG" && INIT_LOG=$LOG || INIT_LOG=$PWD/tools/sh/log.sh

test -n "$sh_src_base" || sh_src_base=/src/sh/lib
test -n "$sh_util_base" || sh_util_base=/tools/sh

test -n "$U_S" -a -d "$U_S" || . $PWD$sh_util/parts/env-0-u_s.sh
test -n "$U_S" -a -d "$U_S" || return

test -n "$scriptpath" || scriptpath="$(dirname "$(dirname "$(dirname "$0")" )" )"
test -n "$scriptname" || scriptname="$(basename "$0")"
test -n "$script_util" || script_util="$U_S$sh_util_base"

#test -n "$1" && {
#  SCRIPTPATH=$1:$scriptpath
#} || {
#  SCRIPTPATH=$(pwd -P):$scriptpath
#}

# Now include module with `lib_load`
test -z "$DEBUG" || echo . $U_S$sh_src_base/lib.lib.sh >&2
{
  . $U_S$sh_src_base/lib.lib.sh || return
  lib_lib_load && lib_lib_loaded=1 || return
  lib_lib_init
} ||
  $INIT_LOG "error" "$scriptname:init.sh" "Failed at lib.lib $?" "" 1

# And conclude with logger setup but possibly do other script-util bootstraps.

test -n "$3" && init_sh_libs="$3" || init_sh_libs=sys\ os\ str\ script

test "$init_sh_libs" = "0" || {
  lib_load $init_sh_libs

  test -n "$2" && init_sh_boot="$2" || init_sh_boot=stderr-console-logger
  script_init "$init_sh_boot"
}

test -n "$LOG_ENV" && unset LOG_ENV INIT_LOG || unset LOG_ENV INIT_LOG LOG

shift 3

eval "$@"

# Sync: U-S:tools/sh/init-here.sh
# Id: script-mpe/0.0.4-dev tools/sh/init-here.sh
