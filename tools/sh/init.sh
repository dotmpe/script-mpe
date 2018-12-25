#!/bin/sh

# This is for sourcing into a standalone or other env boot/init script (ie. CI)


test -n "$LOG" && LOG_ENV=1 || LOG_ENV=
test -n "$LOG" -a -x "$LOG" && INIT_LOG=$LOG || INIT_LOG=$PWD/tools/sh/log.sh

test -n "$sh_src_base" || sh_src_base=/src/sh/lib
test -n "$sh_util_base" || sh_util_base=/tools/sh

test -e "$U_S" || U_S=$HOME/project/user-scripts
test -e "$U_S" || U_S=$HOME/build/user-tools/user-scripts
test -e "$U_S" || unset U_S

# Must be started from u-s project root or set before, or provide SCRIPTPATH
test -n "$scriptpath" || scriptpath="$PWD"
test -n "$scriptname" || scriptname="`basename "$0"`"
test -n "$script_util" || script_util="$U_S$sh_util_base"

# XXX: cleanup
#test -n "$script_env" || {
#  test -e "$PWD$sh_util_base/user-env.sh" &&
#    script_env=$PWD$sh_util_base/user-env.sh ||
#    script_env=$U_S$sh_util_base/user-env.sh
#}
#
#$INIT_LOG "info" "" "Loading user-script env..." "$script_env"
#. "$script_env"

# Now include module with `lib_load`
test -z "$DEBUG" ||
  echo . $U_S$sh_src_base/lib.lib.sh >&2
{
#util_mode=ext . ./util.sh
#unset util_mode
. $U_S$sh_src_base/lib.lib.sh &&
  lib_lib_load && lib_lib_loaded=1 &&
  lib_lib_init
} ||
  $INIT_LOG "error" "init.sh" "Failed at lib.lib $?" "" 1


# And conclude with logger setup but possibly do other script-util bootstraps.

test "$init_sh_libs" = "0" || {
  test -n "$init_sh_libs" -a "$init_sh_libs" != "1" ||
    init_sh_libs=sys\ os\ str\ script\ log\ shell

  $INIT_LOG "info" "sh:init" "Loading" "$init_sh_libs"
  test -n "$LOG" || LOG=$INIT_LOG

  lib_load $init_sh_libs ||
    $INIT_LOG "error" "init.sh" "Failed loading libs: $?" "$init_sh_libs" 1

  lib_init $init_sh_libs ||
    $INIT_LOG "error" "init.sh" "Failed init'ing libs: $?" "$init_sh_libs" 1

  test -n "$init_sh_boot" || init_sh_boot=1
  test -n "$init_sh_boot" && {
    test "$init_sh_boot" != "0" || init_sh_boot=null
    test "$init_sh_boot" != "1" || init_sh_boot=stderr-console-logger
  }

  test -z "$DEBUG" ||
    echo script_util=$U_S$sh_util_base scripts_init $init_sh_boot >&2
  script_util=$U_S$sh_util_base scripts_init $init_sh_boot ||
    $INIT_LOG "error" "init.sh" "Failed at bootstrap '$init_sh_boot' $?" "" 1

}

test -n "$LOG_ENV" && unset LOG_ENV INIT_LOG || unset LOG_ENV INIT_LOG LOG

# Id: script-mpe/0.0.4-dev tools/sh/init.sh
