#!/bin/sh

# stdio/stderr/exit util
log()
{
	[ -n "$(echo "$*")" ] || return 1;
	echo "[$scriptname.sh:$cmd] $1"
}
err()
{
	[ -n "$(echo "$*")" ] || return 1;
	#[ "$VERBOSITY" -ge 1 ] && echo "Error: $1 [$scriptname.sh:$cmd]" 1>&2
	echo "$1 [$scriptname.sh:$cmd]" 1>&2
	[ -n $2 ] && exit $2
}


