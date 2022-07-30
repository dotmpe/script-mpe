#!/bin/sh

## Lib to bootstrap User-Script executables

user_script_lib_load()
{
  # Special userspec to any source/format listing user shell commands.
  # Globs and non-existing paths allowed.
  test -n "${user_cmd_lists-}" ||
      user_cmd_lists=~/.alias\ ~/.bash_alias\ ~/.bash_history\ ~/.conf/etc/git/base.config
}

user_script_lib_init ()
{
  test "${user_script_lib_init-}" = "0" && return

  true "${uname:="$(uname -s)"}"
  true "${US_BIN:=$HOME/bin}"
  true "${SCRIPT_ETC:=$US_BIN/etc}"
  lib_load ignores
}

user_script_find () # ~ # Find executables from user-dirs
{
  test $# -gt 0 || set -- $US_BIN $UCONF/script $UCONF/path/$uname
  # $UCONF/script/$uname $UCONF/script/Generic

  local find_ignores
  find_ignores="$(ignores_find ~/bin/.htdignore.names | tr '\n' ' ')"

  local bd
  for bd in "$@"
  do
    eval "find $bd/ -false $find_ignores -o -executable -type f -print"
  done
}

user_script_check () # ~ # See that every script has a description
{
  user_script_find | user_script_filter | user_script_check_description
}

user_script_check_description () # ~ #
{
  while IFS= read -r execname
  do
    grep -q '^###* [A-Z]' "$execname" || {
        echo "No matches for <$execname>" >&2
        echo "$execname"
    }
  done
}

user_script_filter () # ~ #
{
  local execname mime
  while IFS= read -r execname
  do
    mime=$(file -bi "$execname")

    fnmatch "application/*" "$mime" && {
        echo "Skipping check of binary file <$execname>" >&2
        continue
    }

    fnmatch "text/*" "$mime" ||  {
        echo "Unexpected type <$execname>" >&2
        continue
    }

    fnmatch "*.sh" "$execname" || {
        fnmatch "*.bash" "$execname" || {
            {
                head -n 1 "$execname" | grep -q '\<\(bash\|sh\)\>'
            } || {
                echo "Skipping non-shell scripts for now <$execname>" >&2
            }
        }
    }

    echo "$execname"
  done
}

# Look for command (ie. in history, aliases) given basic regex. To turn on
# extended regex set `ext` flag. Multple matches possible.
#
# This looks at user-cmd-lists, a user-spec ossibly derived from package
# metadata. To look at other scripts use `htd git-grep`, or see user-script'
# env functions. In particular see LIB_SRC and ENV_SRC for scripts to grep.
htd_user_find_command () # [grep_flags] [ext] ~ REGEX
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
  for flag in $(echo $(eval "echo \"\${${1}_flags-}\"") | sed 's/./&\ /g')
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

grep_or ()
{
  printf '\(%s\)' "$(
        printf '%s' "$*" | sed '
                s/ /\\|/g
                s/\*/.*/g
            '
    )"
}

# Extract simple, single-line case/esac cases
sh_type_esacs () # ~ <Func>
{
  sh_type_esacs_fmt "$1" | sh_type_esacs_grep
}

sh_type_esacs_fmt ()
{
  type "$1" | sed -z '
        s/)\n */ ) /g
        s/\n *;;/ ;;/g
        s/\([^;]\);\n */\1; /g
    '
}

sh_type_esacs_grep ()
{
  grep -Po ' \(? .* \) .* set -- [a-z_:-][a-z0-9_:-]* .* ;;'
}

#
