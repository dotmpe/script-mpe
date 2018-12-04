#!/bin/sh

# Must be started from u-s project root or set before
test -n "$scriptpath" || scriptpath="$(pwd -P)"
test -n "$sh_util_base" || sh_util_base=/tools/sh

# if not provided, auto-setup env
# assuming execution starts in script dir (project root)
test -n "$SCRIPTPATH" && {

  SCRIPTPATH=$scriptpath:$SCRIPTPATH
} || {

  SCRIPTPATH=$scriptpath$sh_src_base
}

test -n "$script_util" || script_util="$U_S$sh_util_base"


# Now include module loader with `lib_load`, setup by hand
#__load_mode=ext . $scriptpath/lib.lib.sh
__load_mode=ext . ./util.sh
unset __load_mode
lib_lib_load && lib_lib_loaded=1 ||
  $LOG "error" "init.sh" "Failed at lib.lib $?" "" 1

# Id: script-mpe/0.0.4-dev tools/sh/init.sh
