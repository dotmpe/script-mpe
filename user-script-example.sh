#!/usr/bin/env bash

### User-script example

## Bootstrap

us-env -r user-script || ${us_stat:-exit} $?
#test -n "${uc_lib_profile:-}" ||
#  . "${UCONF:?}/etc/profile.d/bash_fun.sh" || ${us_stat:-exit} $?
#
#uc_script_load user-script || ${us_stat:-exit} $?

# Define aliases immediately, before defining anymore functions (so they expand
# ie. typeset properly and are defined/enabled for main script_{entry,run}
# handler)
#! script_isrunning "user-script-example" .sh ||
#  uc_script_load user-script us-als-mpe || ${us_stat:-exit} $?


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

# main properties
user_script_example_name="User-script+example"
user_script_example_version=0.0.1-dev
user_script_example_maincmds=
user_script_example_shortdescr=
user_script_example_extusage=

#user_script_example__libs=
#user_script_example_foo__grp=user-script-example
#user_script_example_baz__grp=user-script-example


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
