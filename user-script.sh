#!/bin/sh

## Main source to bootstrap User-Script executables


user_script_name="User-script"
user_script_version=0.0.1-dev

# Execute when script is sourced, when given base matches scriptname. If
# need to run this scriptname can be set, but normally this
# gets the correct string to decide wether to execute.
#
# If the function prefixes don't match the exec name, use
# base var to change that.
#
script_entry () # [script{name,_basext},base] ~ <Scriptname> <Arg...>
{
  script_name || return
  if script_isrunning "$1"
  then
    user_script_shell_env || return
    : "${base:="$1"}"
    shift
    script_doenv "$@" || return
    stdmsg '*debug' "User-Script entry now"
    "$@" || script_ret=$?
    script_unenv
    return ${script_ret:-0}
  fi
}

script_cmdid ()
{
  script_cmd="$1"

  mkvid "$1"; script_cmdid=$vid
  test -z "$script_cmdals" || {
      mkvid "$script_cmdals"; script_cmdalsid=$vid
    }
}

# Handle env setup (vars & sources) for script-entry
script_doenv ()
{
  user_script_loadenv || { ERR=$?
    printf "ERR%03i: Cannot load user-script env" "$ERR" >&2
    return $ERR
  }

  mkvid "$base"; baseid=$vid
  script_cmdid "$1"

  ! sh_fun "${baseid}"_loadenv || {
    "${baseid}"_loadenv || return
  }

  test -z "${DEBUGSH:-}" || set -x
}

# Check if given argument equals zeroth argument.
script_isrunning () # [scriptname] ~ <Scriptname> # argument matches zeroth argument
{
  script_name
  #shellcheck disable=2086
  test "$scriptname" = "$1"
}

# Undo env setup for script-entry (inverse of script-doenv)
script_unenv ()
{
  set +e
  test "$IS_BASH" = 1 -a "$IS_BASH_SH" != 1 && set +uo pipefail
  test -z "${DEBUGSH:-}" || set +x
}

script_name ()
{
  : "${scriptname:="$(basename -- "$0" ${script_baseext:-})"}"
}


## U-s functions

user_script_aliases () # ~ [<Name-globs...>] # List handlers with aliases
{
  test $# -eq 0 && {
    set -- "[A-Za-z_:-][A-Za-z0-9_:-]*"
  } || {
    set -- "$(grep_or "$*")"
  }

  local bid
  for bid in $(user_script_bases)
  do
    sh_fun "${bid}_defarg" || continue
    sh_type_esacs ${bid}_defarg | sed '
            s/ set -- \([^ ]*\) .*$/ set -- \1/g
            s/ *) .* set -- /: /g
            s/^ *//g
            s/ *| */, /g
            s/"//g
        '
    done | grep "\<$1\>"
}

user_script_bases ()
{
  script_bases="$baseid"
  test "$baseid" = user_script || {
      script_bases="$script_bases user_script"
      ! sh_fun ${baseid}_bases || ${baseid}_bases
  }
  echo "$script_bases"
}

# Output argv line after doing 'default' stuff. Because these script snippets
# have to change the argv of the function, it is not possible to move them to
# subroutines. And user-script implementations will have to copy these scripts,
# and follow changes to it.
user_script_defarg ()
{
  local rawcmd="${1:-}" defcmd=

  # Track default command, and allow it to be an alias
  user_script_defcmd "$@" || set -- "$script_defcmd"

  # Resolve aliases
  case "$1" in

      # Every good citizen on the executable lookup PATH should have these
      ( "-?"|-h|help )
            test $# -eq 0 || shift; set -- user_script_help "$@" ;;
      ( --help|long-help )
            test $# -eq 0 || shift; set -- user_script_longhelp "$@" ;;

      ( --aliases|aliases )
            test $# -eq 0 || shift; set -- user_script_aliases "$@" ;;
      ( --commands|commands )
            test $# -eq 0 || shift; set -- user_script_handlers "$@" ;;
      ( --env|variables )
            test $# -eq 0 || shift; set -- user_script_envvars "$@" ;;

      ( -V|--version|version )
            test $# -eq 0 || shift; set -- script_version "$@" ;;

  esac

  # Print everything using appropiate quoting
  argv_dump "$@"

  # Print defs for some core vars for eval as well
  user_script_defcmdenv "$@"
}

user_script_defcmd ()
{
  true "${script_defcmd:="usage"}"
  test $# -gt 0 && defcmd=0 ||{
    defcmd=1
    return 1
  }
}

user_script_defcmdenv ()
{
  test "$1" = "$rawcmd" \
      && printf "; script_cmdals=" \
      || printf "; script_cmdals='%s'" "$rawcmd"
  printf '; script_defcmd=%s' "$script_defcmd"
  printf '; script_cmddef=%s' "$defcmd"
}

user_script_envvars () # ~ # Grep env vars from loadenv
{
  local bid
  for bid in $(user_script_bases)
  do
    sh_fun "${bid}_loadenv" || continue
    type "${bid}_loadenv" | grep -Eo -e '\${[A-Z_]+:=.*}' -e '[A-Z_]+=[^;]+' |
        sed '
              s/\([^:]\)=/\1 = /g
              s/\${\(.*\)}$/\1/g
              s/:=/ ?= /g
          '
    continue
  done
}

user_script_handlers () # ~ [<Name-globs...>] # Grep function defs from main script
{
  test $# -eq 0 && {
    set -- "[A-Za-z_:-][A-Za-z0-9_:-]*"
  } || {
    set -- "$(grep_or "$@")"
  }

  # NOTE: some shell allow all kinds of characters.
  # sometimes I define scripts as /bin/bash and use '-', maybe ':'.

  for name in $scriptname.$script_baseext user-script.sh
  do
    script_src=$(command -v "$name") slf_h=1 script_listfun "$1"
  done
}

# By default show short help of only usage and main commands if available.
# About 10, 20, 25 lines tops telling about the script and its entry points.
#
# Through other options, display every or specific parts. Help parts are:
# global aliases, envvars, handlers and usage per handler.
#
# The main options are:
#  -h|help for short help, like usage
#  --help|long-help for help with all main commands, aliases and env
#
# With argument, display only help parts related to matching function(s).
user_script_help () # ~ [<Name>]
{
  # First display generic or handler usage.
  sh_fun "${baseid}"_usage \
      && "${baseid}"_usage "$@" \
      || user_script_usage "$@"

  # Include only main functions unless longhelp isset
  test ${longhelp:-0} -eq 0 -o $# -ne 0 || set -- "*"

  # Go with it, list all specs
  sh_fun "${baseid}"_maincmds \
      && "${baseid}"_maincmds "$@" \
      || user_script_maincmds "$@"

  # Add more parts for generic usage
  test $# -ne 0 || {

    # Add env-vars block, if there is one
    test ${longhelp:-0} -eq 0 || {
      envvars=$( user_script_envvars | sed 's/^/\t/' )
      test -z "$envvars" ||
          printf 'Env vars:\n%s\n\n' "$envvars"
    }
  }
}

# Default loadenv for user-script, run at the end of doenv just before
# deferring to handler.
user_script_loadenv ()
{
  true "${US_BIN:="$HOME/bin"}"

  user_script_loaded=1
}

user_script_longhelp () # ~ [<Name>]
{
  longhelp=1 user_script_help "$@"
}

user_script_maincmds="help long-help aliases commands variables version"

# It is convenient to have a short-ish table, that gives the user an overview
# of which main command handlers a script has. For small scripts this can be
# simply the aliases table. As the script grows, or if aliases are not used
# this may not suffice.
user_script_maincmds () # ~ [<Name-globs...>]
{
  local hdr
  test $# -gt 0 && {
    test "$1" = "*" && hdr="Commands" || hdr="Option"
  } || {
    local var=${baseid}_maincmds
    set -- ${!var:-}
    test $# -gt 0 || set -- $user_script_maincmds
    hdr="Main commands"
  }
  test ${quick:-0} -eq 0 && {

    # Cache aliases we care about and build sed-rewrite to prefix to handlers
    user_script_aliases=$(user_script_aliases "$*" |
          sed 's/^\(.*\): \(.*\)$/\2 \1/' | tr -d ',' )
    alias_sed=$( echo "$user_script_aliases" | while read -r handler aliases
            do
                printf 's/\<%s\>/( %s | & )/\n' "$handler" "${aliases// / | }"
            done
        )
    handlers=$(user_script_resolve_aliases "$@" | remove_dupes | lines_to_words)

    printf '%s:\n%s\n\n' "$hdr" "$(
            user_script_handlers $handlers |
                sed "$alias_sed" |
                    sed 's/^/\t/'
        )"
  } || {
    printf 'Main aliases:\n%s\n\n' "$( user_script_aliases $* | sed 's/^/\t/' )"
  }
}

# This should be run before calling any function
user_script_shell_env ()
{
  ! test "${user_script_shell_env:-}" = "1" || return 0

  user_script_shell_env=0

  user_script_loadenv

  set -e

  {
    . "$US_BIN"/str-htd.lib.sh &&
    . "$US_BIN"/os-htd.lib.sh &&
    . "$US_BIN"/argv.lib.sh &&
    . "$US_BIN"/user-script.lib.sh && user_script_lib_load

    #. ~/project/user-script/src/sh/lib/shell.lib.sh
    . /src/local/user-conf-dev/script/shell-uc.lib.sh
  } || return

  # Restore SHELL setting to proper value if unset
  true "${SHELL:="$(ps -q $$ -o command= | cut -d ' ' -f 1)"}"

  # Set everything about the shell we are working in
  shell_uc_lib_load || { ERR=$?
    printf "ERR%03i: Cannot initialze Shell lib" "$ERR" >&2
    return $ERR
  }

  test "$IS_BASH" = 1 -a "$IS_BASH_SH" != 1 && {

    set -u # Treat unset variables as an error when substituting. (same as nounset)
    set -o pipefail #

    test -z "${DEBUG:-}" || {

      set -h # Remember the location of commands as they are looked up. (same as hashall)
      set -E # If set, the ERR trap is inherited by shell functions.
      set -T
      set -e
      shopt -s extdebug
    }
  }

  user_script_shell_env=1
}

user_script_resolve_aliases ()
{
  for alias in "$@"
  do
    echo "$user_script_aliases" | while read -r handler aliases
    do
      test "$handler" = "$alias" && {
          echo $handler
      } || {
          case " $aliases " in ( *" $alias "* ) echo $handler ; break ;; esac
      }
      true
    done
  done
}

user_script_usage='This is a boilerplate to write executable shell scripts. See
help and specifically help user-script for more info'

# Display description how to evoke command or handler
user_script_usage ()
{
  local usage var=${baseid}_usage
  usage=${!var:-}
  test $# -eq 0 && {
    printf 'Usage:\n\t%s <Command <Arg...>>\n\t%s (%s)\n\n' \
        "$base" \
        "$base" "$script_defcmd"
    printf '%s\n\n' "$usage"
  } || {
    printf 'Usage:\n\t%s %s <Arg...>\n\n' "$base" "$1"
    #printf '%s\n\n' "$_usage"
  }
}

script_version () # ~
{
  local name version var
  var=${baseid}_name; name=${!var:-}
  var=${baseid}_version; version=${!var:-}
  echo "$name/$version"
}


## Other functions

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

# TODO: eval this as part of us-load. Maybe use $3 or $6 or $9...
#
# use alt-io to comm with user, message class indicates severity usage,
# and may include requested facility or script basename. The caller has no
# control over where the messages go, different systems and execution
# environments may place specific restrictions. However at least some of the
# severity levels cannot be ignored, if the given base matches the current
# scripts' basename. Giving no base results in a warning in itself, unless
# some other preconditions are met usually indicating a prepared script (ie.
# batch not interactive user) environment.
#
stdmsg () # ~ <Class> <Message>
{
  true "${v:="${verbosity:-4}"}"
  case "$1" in
      ( *"emerg" ) ;;
      ( *"alert" ) test "$v" -gt 0 || return 0 ;;
      ( *"crit" )  test "$v" -gt 1 || return 0 ;;
      ( *"err" )   test "$v" -gt 2 || return 0 ;;
      ( *"warn" )  test "$v" -gt 3 || return 0 ;;
      ( *"note" )  test "$v" -gt 4 || return 0 ;;
      ( *"info" )  test "$v" -gt 5 || return 0 ;;
      ( *"debug" ) test "$v" -gt 6 || return 0 ;;
  esac
  echo "$2" >&2
}

stdstat ()
{
  type sh_state_name >/dev/null 2>&1 &&
    stdmsg '*note' "$(sh_state_name "$1"): $2" ||
    stdmsg '*note' "Status was $1: $2"
  exit $1
}

script_listfun () # [script-src] ~ [<Grep>] # Wrap grep for function declarations scan
{
  true "${script_src:="$(test -e "$0" && echo "$0" || command -v "$0")"}"
  fun_flags slf ht
  grep "^$1 *() #" "$script_src" | {
    test $slf_h = 1 && {
      sed '
        s/ *() *# [][(){}a-zA-Z0-9=,_-]* *~ */ /g
        s/# \([^~].*\)/\n\t\1\n/g
      '
    } || {
      sed '
        s/ *() *//
        s/# \~ */#/
      ' | tr -s '#' '\t' | {
        test $slf_t = 1 && {
          cat
        } || {
          column -c3 -s "$(printf '\t')" -t |
            sed 's/^/\t/'
        }
      }
    }
  }
}

usage ()
{
  script_version "$@" >&2
  user_script_help "$@" >&2
  # Exit non-zero unless command was given
  test "$script_cmddef" = "0"
}


# Main boilerplate (mostly useless for this script)

! script_baseext=.sh script_isrunning "user-script" || {

  #. "${US_BIN:-"$HOME/bin"}"/user-script.sh
  user_script_shell_env
  eval "set -- $(user_script_defarg "$@")"
  script_baseext=.sh
  # Execute argv and end shell
  script_entry "user-script" "$@" || exit
}

user_script_loaded=0
#
