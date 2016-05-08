#!/bin/sh

# source-script <scriptname> [<paths>]
source_script()
{
	test -n "$2" || {
		test -n "$SCRIPTPATH" || {
			echo "Global SCRIPTPATH required to use source_script"; exit 2
		}
		# Set default include path
		set -- "$1" "$SCRIPTPATH"
	}
	# Don't expose local PATH with script lib dirs
	local PATH=$2:$PATH
	# Do import script into current shell
	. $1 load-*
}

