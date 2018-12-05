#!/bin/sh

# Must be started from u-s project root or set before
test -n "$scriptpath" || scriptpath="$(pwd -P)"
test -n "$sh_util_base" || sh_util_base=/tools/sh

# if not provided, auto-setup env
# assuming execution starts in script dir (project root)
SCRIPTPATH_=$scriptpath/contexts:$scriptpath/commands:$scriptpath
SCRIPTPATH_=$SCRIPTPATH_:$HOME/build/bvberkum/user-scripts/src/sh/lib
SCRIPTPATH_=$SCRIPTPATH_:$HOME/build/bvberkum/user-conf/script
SCRIPTPATH_=$SCRIPTPATH_:$HOME/lib/sh

test -n "$SCRIPTPATH" && {

  SCRIPTPATH=$SCRIPTPATH_:$SCRIPTPATH
} || {

  SCRIPTPATH=$SCRIPTPATH_
}
unset SCRIPTPATH_
export SCRIPTPATH

test -n "$script_util" || script_util="$U_S$sh_util_base"


# Now include module loader with `lib_load`, setup by hand
#lib_mode=ext . $scriptpath/lib.lib.sh
util_mode=ext . ./util.sh
unset util_mode
lib_lib_load && lib_lib_loaded=1 ||
  $LOG "error" "init.sh" "Failed at lib.lib $?" "" 1


# And conclude with logger setup but possibly do other script-util bootstraps.

test "$init_sh_libs" = "0" || {
  test -n "$init_sh_libs" -a "$init_sh_libs" != "1" ||
    init_sh_libs=sys\ os\ str\ script

  lib_load $init_sh_libs ||
    $LOG "error" "init.sh" "Failed at loading libs '$init_sh_libs' $?" "" 1


  test -n "$init_sh_boot" || init_sh_boot=1
  test -n "$init_sh_boot" && {
    test "$init_sh_boot" != "0" || init_sh_boot=null
    test "$init_sh_boot" != "1" || init_sh_boot=stderr-console-logger
  }

  scripts_init $init_sh_boot ||
    $LOG "error" "init.sh" "Failed at bootstrap '$init_sh_boot' $?" "" 1

}

# Id: script-mpe/0.0.4-dev tools/sh/init.sh
