#!/bin/sh

# Use hyphen to ignore source exec in login shell
if [ -n "$0" ] && [ $0 != "-bash" ]; then

  # Do something (only) if script invoked as '$scriptname'
  case "$base" in
    $scriptname )
      main $*
      ;;

    * )
      log "No frontend for $base"
      ;;

  esac
fi

