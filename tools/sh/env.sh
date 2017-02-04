#!/bin/sh

# Keep current shell settings and mute while preparing env, restore at the end
shopts=$-
set +x
set -e

# Restore shell -e opt
case "$shopts"

  in *e* )
    test "$EXIT_ON_ERROR" = "false" -o "$EXIT_ON_ERROR" = "0" && {
      # undo Jenkins opt, unless EXIT_ON_ERROR is on
      echo "[$0] Important: Shell will NOT exit on error (EXIT_ON_ERROR=$EXIT_ON_ERROR)"
      set +e
    } || {
      echo "[$0] Note: Shell will exit on error (EXIT_ON_ERROR=$EXIT_ON_ERROR)"
      set -e
    }
    ;;

  * )
    # Turn off again
    set +e
    ;;

esac


req_var scriptdir
req_var SCRIPTPATH
req_var LIB


### Start of build job parameterisation

req_var DEBUG || DEBUG=
req_var ENV || ENV=development









### Env of build job parameterisation


# Restore shell -x opt
case "$shopts" in
  *x* )
    case "$DEBUG" in
      [Ff]alse|0|off|'' )
        # undo verbosity by Jenkins, unless DEBUG is explicitly on
        set +x ;;
      * )
        echo "[$0] Shell debug on (DEBUG=$DEBUG)"
        set -x ;;
    esac
  ;;
esac

# Id: script-mpe/0.0.3-dev tools/sh/env.sh
