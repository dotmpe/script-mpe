#!/bin/sh

script_isrunning () # ~ <Scriptname>
{
  test "${base:-"$(basename -- "$0" ${script_baseext:-})"}" = "$1"
}

# Execute when script is sourced, when given base matches script-name.
script_entry () # ~ <Scriptname> <Arg...>
{
  test -z "${base:-}" || return 0

  if script_isrunning "$1"
  then
    base="$1"
    shift
    test $# -gt 0 || set -- ${script_defcmd:-"usage"}
    script_doenv
    stdmsg '*debug' "User-Scripts entry now"
    "$@" || script_ret=$?
    script_unenv
    return ${script_ret:-0}
  fi
}

script_doenv ()
{
  set -e
  test "${user_scripts_loaded:-}" = "1" || {
    user_scripts_load || stdexit 123 "Cannot load user-scripts lib"
  }
  #. ~/project/user-scripts/src/sh/lib/shell.lib.sh
  . /src/local/user-conf-dev/script/shell-uc.lib.sh

  true "${SHELL:="$(ps -q $$ -o command= | cut -d ' ' -f 1)"}"
  shell_uc_lib_load || stdstat 123 "Cannot load shell-uc lib"

  mkvid "$base"; baseid=$vid

  ! sh_fun ${baseid}_loadenv || ${baseid}_loadenv

  script_dodebug
}

script_unenv ()
{
  set +e
  script_undebug
}

script_dodebug ()
{
  test -z "${DEBUG:-}" || set -x
}

script_undebug ()
{
  test -z "${DEBUG:-}" || set +x
}


user_script_defarg ()
{
  # Every good citizen on the executable lookup PATH should have
  case "${1:-}" in
      ( "-?" | "-h" | "--help" ) test $# -eq 0 || shift; set -- help "$@" ;;
      ( "-V" | "--version" ) test $# -eq 0 || shift; set -- version "$@" ;;
  esac

  echo "$*"
  # XXX: could properly quote arguments but there is little need for now
  return
  test $# -eq 0 || foreach "$@"
  act=quote_str s="" p="" foreach_do "$@"
}

user_scripts_load ()
{
  ! test "${user_scripts_loaded:-}" = "1" || return 0
  stdmsg '*info' "User-Scripts loading..."
  . ~/bin/str-htd.lib.sh
  . ~/bin/os-htd.lib.sh
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
      ( *"alert" ) test $v -gt 0 || return 0 ;;
      ( *"crit" ) test $v -gt 1 || return 0 ;;
      ( *"err" ) test $v -gt 2 || return 0 ;;
      ( *"warn" ) test $v -gt 3 || return 0 ;;
      ( *"note" ) test $v -gt 4 || return 0 ;;
      ( *"info" ) test $v -gt 5 || return 0 ;;
      ( *"debug" ) test $v -gt 6 || return 0 ;;
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
  # shellcheck disable=SC2015
  test $# -eq 0 && { {
    cat <<EOM
Usage:
$( sh_fun ${baseid}_usage &&
    ${baseid}_usage || printf "\t%s <Command <Arg...>>" "$base" )

Commands:
EOM
  } >&2; }

  # NOTE: some shell allow all kinds of characters.
  # sometimes I define scripts as /bin/bash and use '-', maybe ':'.
  script_listfun "${1:-"[A-Za-z_:-][A-Za-z0-9_:-]*"}" | sed 's/^/\t/'
}

script_listfun ()
{
  true "${script_src:="$(test -e "$0" && echo "$0" || command -v "$0")"}"

  # XXX: foreach...
  grep "^$1 () #" "$script_src" | sed '
        s/ () //
        s/# \~/#/
      ' |
    tr -s '#' '\t' | column -c3 -s "$(printf '\t')" -t
}


# Main

! script_baseext=.sh script_isrunning "user-scripts" || {

  user_scripts_load
  eval "set -- $(user_script_defarg "$@")"
  stdmsg '*info' "User-Scripts starting..."
  script_baseext=.sh
  script_entry "user-scripts" "$@"
}

user_scripts_loaded=0
#
