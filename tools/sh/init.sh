#!/bin/sh


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

# Now include script to source other utils
. $scriptdir/util.sh

# Id: script-mpe/0.0.3-dev tools/sh/init.sh
