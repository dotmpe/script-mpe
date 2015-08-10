#/!usr/bin/bash

# Statusdir - a lightweight property store for bash

# Does not store actual properties yet, and the tree files are not actually used.
# The files in the index are used to store lists of keys, see env.sh

set -e

[ -z "$STATUSDIR_ROOT" ] && {
    STATUSDIR_ROOT="$(echo ~/.statusdir/)"
    #export STATUSDIR_ROOT
}

statusdir_root()
{
	path=$STATUSDIR_ROOT
	[ -e "$path" ] || mkdir -p $path
	echo $path
}

# Make path in statusdir exists, args are pathelems
# echos path
statusdir_assert()
{
	tree=$(echo $@ | tr ' ' '/')
	path=$STATUSDIR_ROOT"tree/"$tree
	mkdir -p $path
	echo $path
	#export statusdir_tree=$tree
}

# As statusdir_assert, but last arg is filename
# (does not touch file, but echos it)
statusdir_dir()
{
	tree=$(echo $@ | tr ' ' '/')
	path=$STATUSDIR_ROOT"index/"$tree
	mkdir -p $(dirname $path)
	echo $path
}

# Specific statusdir_dir assert for .list file
statusdir_index()
{
	tree=$(echo $@ | tr ' ' '/')
	path=$STATUSDIR_ROOT"index/"$tree".list"
	mkdir -p $(dirname $path)
	echo $path
}

# Main
if [ -n "$0" ] && [ $0 != "-bash" ]; then
	# Do something if script invoked as 'statusdir.sh'
	if [ "$(basename $0)" = "statusdir.sh" ]; then
		# invoke with function name first argument,
		func="$1"
		type "statusdir_$func" &>/dev/null && { func="statusdir_$1"; }
		type $func &>/dev/null && {
			shift 1
			$func $@
		# or run default
		} || { 
			exit
		}
	fi
fi
