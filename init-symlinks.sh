#!/usr/bin/env bash

LOG=~/project/mkdoc/usr/share/mkdoc/Core/log.sh

check_hosted() # hostnames ...
{
	case `hostname -s` in "$@" )
			return 0
		;;
	esac

	return 1
}

do_symlink() # source destination host(s)
{
	# return if line not for this host
	args=($@)
	hosts=${args[@]:2}
	check_hosted $hosts
	if test -n "$hosts" -a $? -ne 0; then 
		return; 
	fi;

	# Get paths from args, expanding any ENV variables
	target=`eval echo "$1"`
	path=`eval echo "$2"`

	$LOG	debug init-symlinks "Evaluating" $path

	# fail if relative paths in line
	if test "${path:0:1}" != "/" -a "${target:0:1}" != "/";
	then
		echo "Need absolute path, got $path -> $target"
		exit -2
	fi

	# if link, check target
	if test -h "$path" -a "`readlink $path`" != "$target"
	then
		echo "Removing path"
		rm "$path"
	fi

	if test ! -L "$path"
	then
		if test ! -e "$path"
		then
			#echo "$path <(symlinking) $target"
			echo "new link: $path -> $target"
			ln -s "$target" "$path"
		else
			echo "Not linking to existing non link $path"
		fi
	else
		if test `readlink $path` != $target; then
			echo "Cannot link $target $path";
		fi;
	fi
}

### Main

# Read from file (first arg) -or- stdin
if test -z "$1"; then
	F=~/.conf/symlinks.tab
else
	F=$1
fi

if test "$F" != "-"; then
	if test ! -f "$F"
	then
		echo "Usage: $0 [-|file]"
		exit -1
	fi
	exec 6<&0 # Link fd#6 with stdin
	exec < $F # Replace stdin with file
fi

# Read all lines (from stdin)
$LOG	verbose init-symlinks "Reading from" $F
while read line; do
	# ignore blanks and comments
	if test -n "$line" -a "${line:0:1}" != "#"; then
		do_symlink $line
	fi
done 

if test "$F" != "-"; then
	exec 0<&6 6<&- # restore stdin and close fd#6
fi
