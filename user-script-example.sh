#!/usr/bin/env bash

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script

# ----

user_script_example_loadenv ()
{
  true
}

# an exported function
#at_us_src_scr user-script

# Not a function but an alias that inlines the argv parse boilerplate?
#at_us_load_scr user-script -alsdefs -alsargv
#
#at_us_init_scr user-script -alsdefs -alsargv user-script-example .sh -- "$@"
#at_us_run_scr user-script -alsdefs -alsargv user-script-example .sh -- "$@"

! script_isrunning "user-script-example" ".sh" || {
  # Last chance to transform argv before it is mapped to function

  user_script_load || exit $?

  eval "set -- $(user_script_defarg "$@")"
  #script_run "$@"
}

script_entry "user-script-example" "$@"
