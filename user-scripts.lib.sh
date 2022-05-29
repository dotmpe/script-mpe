#!/bin/sh

user_scripts_lib_load()
{
  # Special userspec to any source/format listing user shell commands.
  # Globs and non-existing paths allowed.
  test -n "${user_cmd_lists-}" ||
      user_cmd_lists=~/.alias\ ~/.bash_alias\ ~/.bash_history\ ~/.conf/etc/git/base.config
}

user_scripts_lib_init()
{
  test "${user_scripts_lib_init-}" = "0" && return
  true
}

# Look for command (ie. in history, aliases) given basic regex. To turn on
# extended regex set `ext` flag. Multple matches possible.
#
# This looks at user-cmd-lists, a user-spec ossibly derived from package
# metadata. To look at other scripts use `htd git-grep`, or see user-scripts'
# env functions. In particular see LIB_SRC and ENV_SRC for scripts to grep.
htd_user_find_command() # [grep_flags] [ext] ~ REGEX
{
  test -n "${1-}" || return
  test -n "$user_cmd_lists" || return
  test -n "$grep_flags" || {
    trueish "$ext" && grep_flags=-nHE || grep_flags=-nH
  }

  note "Looking for user-command '$*'"
  for cmdl_file in $user_cmd_lists
  do
      note "$cmdl_file"
      test -e "$cmdl_file" || continue
    std_info "Looking through '$cmdl_file'..."
    $ggrep $grep_flags "$1" "$cmdl_file" || continue
  done
}

# Function flags: simple but easy run-time flags for function.
# Run every time upon invocation of user-function
# E.g. to the function, this local env:
#   myfunc_flags=aqz myfunc ....
# becomes flag-vars:
#   myfunc_a=1 myfunc_q=1 myfunc_z=1
#
# Giving a flexible run-time configuration of the function with minimal parsing
# and setup. If the user passes any flags, these are guaranteed to be
# default 1. If the function passes any flags, these are guaranteed to be set
# with default 0 for Off or 1 for On.
# Indiviudal flag-vars are never changed if provided by env.
fun_flags () # ~ <Var-Name> [<Flags-Off>] [<Flags-On>]
{
  for flag in $(echo $(eval "echo \"\$${1}_flags\"") | sed 's/./&\ /g')
  do eval "true \${${1}_${flag}:=1}"
  done

  test -z "${2-}" || {
    for flag in $(echo $2 | sed 's/./&\ /g')
    do eval "true \${${1}_${flag}:=0}"
    done
  }

  test -z "${3-}" || {
    for flag in $(echo $3 | sed 's/./&\ /g')
    do eval "true \${${1}_${flag}:=1}"
    done
  }
  unset flag
}

#
