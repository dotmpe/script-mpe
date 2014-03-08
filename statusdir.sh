#/!usr/bin/bash
# Statusdir - a lightweight persisted property store for bash

ROOT="$(echo ~/.statusdir/)"

statusdir_root()
{
	path=$ROOT
	mkdir -p $path
	echo $path
}

statusdir_assert()
{
	tree=$(echo $@ | tr ' ' '/')
	path=$ROOT"tree/"$tree
	mkdir -p $path
	echo $path
	#export statusdir_tree=$tree
}

statusdir_dir()
{
	tree=$(echo $@ | tr ' ' '/')
	path=$ROOT"index/"$tree
	mkdir -p $(dirname $path)
	echo $path
}

statusdir_index()
{
	tree=$(echo $@ | tr ' ' '/')
	path=$ROOT"index/"$tree".list"
	mkdir -p $(dirname $path)
	echo $path
	#export statusdir_tree=$tree
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
