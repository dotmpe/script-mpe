#!/bin/sh

# Use dash to ignore source exec in login shell
if [ -n "$0" ] && [ $0 != "-bash" ]; then

  # Do something (only) if script invoked as '$scriptname'
  case "$base" in
    $scriptname )

      # function name first as argument,
      cmd=$1
      func=$(echo c_$cmd | tr '-' '_')
      func_exists=""

      # load/exec if func exists
      type $func 1> /dev/null 2> /dev/null && {
        func_exists=y
        load
        test -n "$1" && shift 1
        $func $@
        e=0
      } || {
        # handle non-zero return or print usage for non-existant func
        e="$?"
        test -z "$cmd" && {
          load
          usage
          err '' 'No command given, see "help"' 1
        } || {
          test -n "$func_exists" \
            && err '' "Command $cmd returned $e" $e \
            || err '' "No such command: $cmd" 1
        }
      }

      ;;

    * )
      log "No frontend for $base"
      ;;

  esac
fi
