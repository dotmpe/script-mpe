#/!usr/bin/bash

source ~/bin/statusdir.sh

env_props()
{
	comm -3 <(declare | sort) <(declare -f | sort)
}

env_keys()
{
	# read key-names from input and sort into index file
	path=/tmp/env-sortkeys
	test -e $path.tmp && rm $path.tmp
	while read envline
	do
		echo $envline | sed -n 's/^\([A-Z_0-9]*\)\=.*$/\1/p' >> $path.tmp
	done
	sort -u $path.tmp -o $path
	rm $path.tmp
	cat $path
	rm $path
}

env_filter() 
{
	while read key
	do
		[ -z "$key" ] && continue
		$(grep -bqr $key $1) && continue \
			|| echo $key;
	done
}

env_session()
{
	[ -n "$SSH_TTY" ] && { 
		echo ssh_$(echo $SSH_TTY | tr '/' '_')
		return
	}
	[ -n "$TERM" ] && { 
		echo term_$TERM
		return
	}
}

env_root()
{
	statusdir_assert env_$(whoami) $(env_session)
}

env_start()
{
	env_root > /dev/null
	index_file=$(statusdir_index env_$(whoami) $(env_session) "system")
	env_props | env_keys \
		> $index_file
	echo "system="$(cat $index_file | wc -l) \
		>> $(statusdir_assert env_$(whoami) $(env_session))"/stats.sh"
}

env_initialized()
{
	index_file=$(statusdir_index env_$(whoami) $(env_session) "user") 
	env_props | env_keys | env_filter \
		$(statusdir_index env_$(whoami) $(env_session) system) \
		> $index_file
	echo "user="$(wc -l $index_file) \
		>> $(statusdir_assert env_$(whoami) $(env_session))"/stats.sh"
	#diff -y $(statusdir_index env_$(whoami) $(env_session) "system") $index_file 
}

env_tree()
{
	root=$(env_root)
	index_root=$(statusdir_dir env_$(whoami) $(env_session)) 
	echo root=$root
	echo index_root=$index_root
	tree $root $index_root
}
env_list()
{
	index="$1"
	[ -z "$index" ] && {
		index="user"
	}
	index_file=$(statusdir_index env_$(whoami) $(env_session) $index)
	echo index_file=$index_file
	echo $(cat $index_file)
}
# Main
if [ -n "$0" ] && [ $0 != "-bash" ]; then
	# Do something if script invoked as 'vc.sh'
	if [ "$(basename $0)" = "env.sh" ]; then
		# invoke with function name first argument,
		func="$1"
		type "env_$func" &>/dev/null && { func="env_$func"; }
		type $func &>/dev/null && {
			shift 1
			$func $@
		# or run default
		} || { 
			exit
		}
	fi
fi
