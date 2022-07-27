#!/bin/sh

## Main source to bootstrap user-scripts executables


# Check if given argument equals zeroth argument.
script_isrunning () # [scriptname] ~ <Scriptname> # argument matches zeroth argument
{
  #shellcheck disable=2086
  test "$scriptname" = "$1"
}

# Execute when script is sourced, when given base matches scriptname. If
# need to run this scriptname can be set, but normally this
# gets the correct string to decide wether to execute.
#
# If the function prefixes don't match the exec name, use
# base var to change that.
#
script_entry () # [script{name,_basext},base] ~ <Scriptname> <Arg...>
{
  : "${scriptname:="$(basename -- "$0" ${script_baseext:-})"}"

  if script_isrunning "$1"
  then
    : "${base:="$1"}"
    shift
    test $# -gt 0 || set -- "${script_defcmd:-"usage"}"
    script_doenv || return
    stdmsg '*debug' "User-Scripts entry now"
    "$@" || script_ret=$?
    script_unenv
    return ${script_ret:-0}
  fi
}

# Handle env setup (vars & sources) for script-entry
script_doenv ()
{
  set -e

  test "${user_scripts_loaded:-}" = "1" || {
    user_scripts_loadenv || { ERR=$?
      printf "ERR%03i: Cannot load user-scripts env" "$ERR" >&2
      return $ERR
    }
  }

  test "$IS_BASH" = 1 -a "$IS_BASH_SH" != 1 && set -uo pipefail
  mkvid "$base"; baseid=$vid

  ! sh_fun "${baseid}"_loadenv || "${baseid}"_loadenv

  test -z "${DEBUG:-}" || set -x
}

# Undo env setup for script-entry (inverse of script-doenv)
script_unenv ()
{
  set +e
  test "$IS_BASH" = 1 -a "$IS_BASH_SH" != 1 && set +uo pipefail
  test -z "${DEBUG:-}" || set +x
}

# Output argv line after doing 'default' stuff
user_script_defarg ()
{
  # Every good citizen on the executable lookup PATH should have
  case "${1:-}" in
      ( "-?" | "-h" | "--help" ) test $# -eq 0 || shift; set -- help "$@" ;;
      ( "-V" | "--version" ) test $# -eq 0 || shift; set -- version "$@" ;;
  esac

  # Print everything using appropiate quoting
  argv_dump "$@"
}

# Default loadenv for user-scripts. This is before anything
# is known about what to source/run.
user_scripts_loadenv ()
{
  ! test "${user_scripts_loaded:-}" = "1" || return 0

  true "${US_BIN:="$HOME/bin"}"

  {
    . "$US_BIN"/str-htd.lib.sh &&
    . "$US_BIN"/os-htd.lib.sh &&
    . "$US_BIN"/argv.lib.sh &&
    #. ~/project/user-scripts/src/sh/lib/shell.lib.sh
    . /src/local/user-conf-dev/script/shell-uc.lib.sh
  } || return

  # Restore SHELL setting to proper value if unset
  true "${SHELL:="$(ps -q $$ -o command= | cut -d ' ' -f 1)"}"

  # Set everything about the shell we are working in
  shell_uc_lib_load || { ERR=$?
    printf "ERR%03i: Cannot initialze Shell lib" "$ERR" >&2
    return $ERR
  }

  user_scripts_loaded=1
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

# Idem as stdmsg, eval on load-init somewhere
help ()
{
  user_script_help "$@"
}
usage ()
{
  user_script_help "$@"
  false
}
version ()
{
  false
}

user_script_help () # ~ [<Name>]
{
  test $# -eq 0 && { {
    cat <<EOM
Usage:
$( sh_fun "${baseid}"_usage &&
    "${baseid}"_usage || printf "\t%s <Command <Arg...>>" "$base" )

Commands:
EOM
  } >&2; }

  # NOTE: some shell allow all kinds of characters.
  # sometimes I define scripts as /bin/bash and use '-', maybe ':'.
  script_listfun_flags=h \
  script_listfun "${1:-"[A-Za-z_:-][A-Za-z0-9_:-]*"}"
}

script_listfun () # ~ # Wrap grep for function declarations scan
{
  true "${script_src:="$(test -e "$0" && echo "$0" || command -v "$0")"}"
  fun_flags script_listfun ht
  # XXX: foreach...
  grep "^$1 *() #" "$script_src" | {
    test $script_listfun_h = 1 && {
      sed '
        s/# \([^\~]\)/\n      \1/
        s/ *() *# ~ */ /
        s/^/    /
      '
    } || {
      sed '
        s/ *() *//
        s/# \~ */#/
      ' | tr -s '#' '\t' | {
        test $script_listfun_t = 1 && {
          cat
        } || {
          column -c3 -s "$(printf '\t')" -t |
            sed 's/^/\t/'
        }
      }
    }
  }
}


# Main boilerplate (mostly useless for this script)

! script_baseext=.sh script_isrunning "user-scripts" || {

  #. "${US_BIN:-"$HOME/bin"}"/user-scripts.sh
  user_scripts_loadenv
  eval "set -- $(user_script_defarg "$@")"
  script_baseext=.sh
  # Execute argv and return
  script_entry "user-scripts" "$@"
}

user_scripts_loaded=0
#
