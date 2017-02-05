#!/bin/sh

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-*" ) ;; * )

  # Do something (only) if script invoked as '$scriptname'
  case "$base" in
    $scriptname )
      main $*
      ;;

    * )
      log "No frontend for $base"
      ;;

  esac

esac


