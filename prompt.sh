#!/bin/sh
# Prompt helpers for persisted session info


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


### Main

# Ignore login console interpreter
case "$0" in "" ) ;; "-*" ) ;; * )

  # Ignore 'load-ext' sub-command
  case "$1" in load-ext ) ;; * )

      set -e

      . ~/bin/std.sh

      scriptname=prompt
      # Do something if script invoked as '$scriptname.sh'
      base=$(basename $0 .sh)
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

              . ~/bin/statusdir.sh
              . ~/bin/vc.sh load-ext
              $func "$@"

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


      esac ;;

  esac ;;

esac

