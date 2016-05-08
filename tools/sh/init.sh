#!/bin/sh

. $scriptdir/tools/sh/source-script.sh


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
source_script util.sh
util_init

