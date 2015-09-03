#/!usr/bin/bash
# Prompt helpers for persisted session info

set -e

source ~/bin/statusdir.sh
source ~/bin/vc.sh

scriptname=prompt


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
# Use dash to ignore exec in login shell
if [ -n "$0" ] && [ $0 != "-bash" ]; then

	# Do something (only) if script invoked as '$scriptname'
	base="$(basename $0 .sh)"
	case "$base" in

		$scriptname )

			# function name first as argument,
			cmd=$1
			[ -n "$def_func" -a -z "$cmd" ] \
				&& func=$def_func \
				|| func=$(echo prompt_$cmd | tr '-' '_')

			# load/exec if func exists
			type $func &> /dev/null && {
				func_exists=1
				shift 1
				$func $@
			} || {
				# handle non-zero return or print usage for non-existant func
				e=$?
				[ -z "$cmd" ] && {
					error 'No command given, see "help"' 1
				} || {
					[ "$e" = "1" -a -z "$func_exists" ] && {
						error "No such command: $cmd" 1
					} || {
						error "Command $cmd returned $e" $e
					}
				}
			}

			;;

		* )
			log "No frontend for $base"
			;;

	esac
fi

# vim:noet:

