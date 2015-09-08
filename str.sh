#!/bin/sh


# ID for simple strings without special characters
mkid()
{
	id=$(echo "$1" | tr '.-' '__')
}

# to filter strings to valid id
mkvid()
{
	vid=$(echo "$1" | sed 's/[^A-Za-z0-9_]\{1,\}/_/g')
	# Linux sed 's/\([^a-z0-9_]\|\_\)/_/g'
}
mkcid()
{
	cid=$(echo "$1" | sed 's/\([^a-z0-9-]\|\-\)/-/g')
}

str_match()
{
	expr "$1" : "$2" &>/dev/null || return 1
}
str_contains()
{
	case $(uname) in
		Linux )
			test 0 -lt $(expr index "$1" "/") || return 1
			;;
		Darwin )
			err "TODO" 1
			echo expr "$1" : "$2"
			expr "$1" : "$2"
			;;
	esac
}

# x-platform regex match since Bash/BSD test wont chooche on older osx
x_re()
{
  echo $1 | grep -E "^$2$" > /dev/null && return 0 || return 1
}

fnmatch () { case "$2" in $1) return 0 ;; *) return 1 ;; esac ; }


