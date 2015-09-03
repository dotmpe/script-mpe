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
	test -n "$1" || 1=Error
	case "$(echo $1 | tr 'A-Z' 'a-z')" in
		warn*|err*|notice ) log "$1: $2" 1>&2 ;;
		* ) log "$2" 1>&2 ;;
	esac
	[ -z $3 ] || exit $3
}
error()
{
	err "Error" "$1" "$2"
}
warn()
{
	err "Warning" "$1" "$2"
}
note()
{
	err "Notice" "$1" "$2"
}
info()
{
  err " " "$1" "$2"
}

