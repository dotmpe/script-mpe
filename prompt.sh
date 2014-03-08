#/!usr/bin/bash
# Prompt helpers for persisted session info

source ~/bin/statusdir.sh
source ~/bin/vc.sh


prompt_command()
{
	#__vc_status $(pwd)

	printenv > /tmp/env.1
	echo '-------------------------'

	( set -o posix ; set ) > /tmp/env.2
	echo '-------------------------'
	diff -y /tmp/env.2 /tmp/env.1
	#diff --left-column /tmp/env.2 /tmp/env.1

	#declare -p > /tmp/env.3
}

# Main
if [ -n "$0" ] && [ $0 != "-bash" ]; then
	# Do something if script invoked as 'prompt.sh'
	if [ "$(basename $0)" = "prompt.sh" ]; then
		# invoke with function name first argument,
		func="$1"
		type "prompt_$func" &>/dev/null && { func="prompt_$func"; }
		type $func &>/dev/null && {
			shift 1
			$func $@
		# or run default
		} || { 
			exit
		}
	fi
fi

