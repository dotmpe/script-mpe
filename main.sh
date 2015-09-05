#!/bin/sh

# Use dash to ignore source exec in login shell
if [ -n "$0" ] && [ $0 != "-bash" ]; then

  # Do something (only) if script invoked as '$scriptname'
  case "$base" in
    $scriptname )
      . $HOME/main.inc.sh
      ;;

    * )
      log "No frontend for $base"
      ;;

  esac
fi
