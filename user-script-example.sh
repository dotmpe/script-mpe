#!/usr/bin/env bash

### User-script example

test -n "${uc_lib_profile:-}" ||
  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${stat:-exit} $?
uc_script_load user-script || ${stat:-exit} $?


## Command handlers

user_script_example_foo ()
{
  echo Libs: ${lib_loaded:-}
}

user_script_example_baz ()
{
  echo Libs: ${lib_loaded:-}
}
user_script_example_baz__libs=status

user_script_example_bar ()
{
  TODO $lk:bar
}


## User-script parts

user_script_example_loadenv ()
{
  #user_script_loadenv || return
  : "${_E_next:=196}"
  script_part=${1:?} user_script_load groups || {
      # E:next means no libs found for given group(s).
      test ${_E_next:?} -eq $? || return $_
    }
  user_script_initlog &&
  $LOG notice "$lk:loadenv" "User script loaded" "[-$-] (#$#) ~ ${*@Q}"
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
