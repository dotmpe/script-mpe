#!/bin/sh

# Must be started from project root.
# Import minimal setup and shell util functions.
test -n "$scriptdir" || scriptdir="$(pwd -P)"

# if not provided, auto-setup env
# assuming execution starts in script dir (project root)
test -n "$SCRIPTPATH" || {
  test -n "$LIB" || {
    test -n "$scriptdir" \
      && LIB=$scriptdir \
      || LIB=$(cd $(dirname $(dirname $0)); pwd -P )
    export LIB
  }
	SCRIPTPATH=$LIB
	# get absolute path for scripts lib dir if LIB is relative
	case "$LIB" in /* ) ;; * )
		SCRIPTPATH="$(cd "$LIB"; pwd -P)"
	;;esac
	export SCRIPTPATH
}

# Now include script and run util_init to source other utils
. $scriptdir/util.sh


req_vars RUN_FLOW || RUN_FLOW=./tools/ci/flow.sh


# Id: script-mpe/0.0.3-dev tools/sh/init.sh
