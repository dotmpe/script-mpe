#/!usr/bin/bash

#
# env_start and env_initialized used in .bashrc
#
# XXX: should initialize before any other user env script
# XXX: should identify session, and print session id info beside pstree
#


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

# Report a unique key for current CLI session
# for bash, made up of either SSH_TTY or else TERM value
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

# Prepare statusdir for root env
env_root()
{
	statusdir_assert env_$(whoami) $(env_session)
}

# Prepare new index for root env; store in statusdir 'system' index
env_start()
{
	# init statusdir for env_$(whoami) $(env_session)
	env_root > /dev/null
	# fill the index file with env keys
	index_file=$(statusdir_index env_$(whoami) $(env_session) "system")
	env_props | env_keys \
		> $index_file
	echo "system="$(cat $index_file | wc -l) \
		>> $(statusdir_assert env_$(whoami) $(env_session))"/stats.sh"
	#echo SSH_TTY=$SSH_TTY
	#echo STY=$STY
}

# Find difference current env with root; store in statusdir 'user' index
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

# print whats in statusdir
env_tree()
{
	sr_root=$(statusdir_root)
	root=$(env_root)
	index_root=$(statusdir_dir env_$(whoami) $(env_session))

	_root=${root##$sr_root}
	_index_root=${index_root##$sr_root}

	echo statusdir_root=$sr_root
	cd $STATUSDIR_ROOT;
	tree $_root $_index_root
}

# read whats in statusdir indices
env_list()
{
	test -n "$1" || set -- "user"
	index_file=$(statusdir_index env_$(whoami) $(env_session) $1)
	echo env_session=$(env_session)
	echo index_file=$index_file
	echo env_vars=$(cat $index_file)
}

env_sessions()
{
	case "$(uname)" in
		Darwin )
			ps axo uid=,tty= | grep -v '??' | sort -u
			;;
		Linux )
			ps axno user,tty | awk '$1 >= 1000 && $1 < 65530 && $2 != "?"' | sort -u
			;;
	esac
}

env_tty()
{
	echo "Current tty is $(tty)"

	case "$(uname)" in
		Darwin )
			ps axo uid=,tty=,pid=,command= | grep -v '??' | sort -u
			#| awk '$1 >= 1000 && $1 < 65530 && $2 != "?"' | sort -u
			;;
		Linux )
			ps axno user,tty,pid,command | awk '$1 >= 1000 && $1 < 65530 && $2 != "?"' | sort -u
			;;
	esac
}


# Main
if [ -n "$0" ] && [ $0 != "-bash" ]; then
	# Do something if script invoked as 'env.sh'
	if [ "$(basename $0)" = "env.sh" ]; then
		# invoke with function name first argument,
		func="$1"
		type "env_$func" &>/dev/null && { func="env_$func"; }
		type $func &>/dev/null && {
			shift 1

			# Use statusdir to store keys
			source ~/bin/statusdir.sh

			$func "$@"

		# or run default
		} || {
			exit 1
		}
	fi
fi
