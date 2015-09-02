#!/bin/sh

# stdio/stderr/exit util
log()
{
	[ -n "$(echo "$*")" ] || return 1;
	echo "[$scriptname.sh:$cmd] $1"
	#[ $level -le $VERBOSE ] && echo "$1"
}
err()
{
	log "$1" 1>&2
	[ -n $2 ] && exit $2
}

error()
{
	test -n "$1" && label=$1 || label=Error
	shift 1
	err "$label: $1"
}

warn()
{
	error "Warning" $1
}

note()
{
	error "Notice" $1
}


