#!/bin/sh

# Must be started from u-s project root or set before
test -n "$scriptpath" || scriptpath="$(pwd -P)"

# if not provided, auto-setup env
# assuming execution starts in script dir (project root)
test -n "$SCRIPTPATH" && {

  SCRIPTPATH=$scriptpath:$SCRIPTPATH
} || {

  SCRIPTPATH=$scriptpath$sh_src_base
}

# Now include script and run util_init to source other utils
__load_mode=ext . ./util.sh
#__load_mode=ext . $scriptpath$sh_src_base/lib.lib.sh
#lib_lib_load

# Id: script-mpe/0.0.4-dev tools/sh/init.sh
