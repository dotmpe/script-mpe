#!/usr/bin/env bash

us-env -r user-script

# Main entry (see user-script.sh for boilerplate)

! script_isrunning "ino" .sh || {
  user_script_load || failerr "E$? user-script-load" || exit

  # Pre-parse arguments
  script_defcmd=check
  user_script_defarg=defarg\ aliasargv

  # FIXME:
  #eval "set -- $(user_script_defarg "$@")"
  script_run "$@"
}
