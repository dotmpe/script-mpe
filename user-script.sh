#!/usr/bin/env bash

## Main source to bootstrap User-Script executables

# Custom scripts can provide <baseid>-*=<custom value> to use local values
user_script_name="User-script"
user_script_version=0.0.1-dev

# The short help only lists main commands
user_script_maincmds="help long-help aliases commands variables version"

# TODO: This short help starts with a short usage.
user_script_shortdescr='This is a boilerplate and library to write executable shell scripts.
See help and specifically help user-script for more info'

# TODO: The long per-sub-command help
#shellcheck disable=2016
user_script_extusage='Custom scripts only need to know where to find
user-script.sh. I'"'"'ll include the current minimal boilerplate here to
illustrate:

    test -n "${user_script_loaded:-}" ||
        . "${US_BIN:="$HOME/bin"}"/user-script.sh
    script_entry "my.sh" "$@"

This would make your (executable) script run at script-entry, if invoked as
`my.sh` (or when included in a script invoked as such). But not when called or
sourced otherwise. Basically only if SCRIPTNAME == entry-argument.

Generic env settings:
    DEBUG - To enable some bash-specific trace/debug shell settings.
    DEBUGSH - To enable verbose execution (aka sh -x, xtrace; to stderr)
    BASH_VERSION - Used to enable bash-specific runtime options
    quiet - Used to make user-script stop commenting on anything

# Entry sequence
Before entry, user-script-shell-env can be executed to get access at other
functions in the pre-entry stage, such as pre-processing arguments (w. defarg)

Without defarg, there are only one or two more env settings at this point:
    SCRIPT_BASEEXT - Set to strip ".ext" from name
    SCRIPTNAME - Should be no need to set this

At script-entry first the SCRIPTNAME is set and checked with first argument.
user-script-shell-env then gets to run again (if needed), but it only does
some basics for generic user-script things like the help function and
the simple argument pre processing.

- set some environment vars (calling user-script-loadenv)
- load some libraries (basic dependencies for user-script)
- and do some shell specific setups (using shell.lib).

Then script-doenv is called, to do find the handler function and to do further
preparations.
This runs the <baseid>-loadenv hook so custom scripts can do their own stuff.

At that point these variables are provided:
    base{,id} - Same as SCRIPTNAME, and an ID created from that
    script-cmd{,id,alsid} - The first argument, and an ID created from that.
        And also from an alias if set (see defarg)

After do-env it is expected that "$1" equals the name of a shell function, if
not then "usage" (fail) is invoked instead.
do-env can not change arguments,
either the handler does further argv processing or defarg takes care of it.

script-doenv is paired with a script-unenv, called after the command.
Both are short steps:

- doenv sets base and baseid,
  calls script-cmdid to set vars,
  and then <baseid>_loadenv

- unenv calls <baseid>_unload,
  and then undoes every of its own settings and unsets vars

During unenv, script-cmdstat holds the return status.

Some of these things may need to be turned into hooks as well.


# Hooks
The current hooks mainly revolve around command alias functionality.

defarg
    Provide <baseid>_defarg and use it to pre-process argv instead of
    user_script_defarg.
    To help user-script-aliases find case/esac items set script-extra-defarg.

    Custom scripts may not want to take on the defarg boilerplate however,
    processing argv is a bit tricky since we use the dump-eval steps,
    and extracting aliases requires the case/esac in-line in the function body.

    Instead user-script-defarg can pick up one script-fun-xtra-defarg,
    which it includes in-line (evals function body).


NOTE: I use user-script-shell-env and user-script-defarg for almost all scripts,
focus is on good online help functions still. And using code/comments to
provide needed data instead of having to give additional variables.

TODO: fix help usage/maincmd so each gives proper info. Some tings mixed up now
'

user_script__libs=user-script


# Execute when script is sourced, when given base matches SCRIPTNAME.
# If the handlers prefixes don't match the exec name, use
# base var to change that.
script_entry () # [script{name,_baseext},base] ~ <Scriptname> <Action-arg...>
{
  local SCRIPTNAME=${SCRIPTNAME:-}
  script_name || return
  if test "$SCRIPTNAME" = "$1"
  then
    shift
    script_run "$@" || return
  else
    ! us_debug ||
      $LOG info :script-entry "Skipped non-matching command" "$1<>$SCRIPTNAME"
  fi
}

script_run () # ~ <Action <argv...>>
{
  script_doenv "$@" || return
  ! uc_debug ||
      $LOG info :uc:script-run "Entering user-script $(script_version)" \
          "cmd:$script_cmd:als:${script_cmdals-(unset)}"
  #stdmsg '*debug' "Entering user-script $(script_version)"
  shift
  ! uc_debug ||
      $LOG info :script-run:$base "Running main handler" "fun:$script_cmdfun:$*"
  "$script_cmdfun" "$@" || script_cmdstat=$?
  script_unenv || return
}

script_baseenv ()
{
  local var var_ _baseid

  : "${base:=${SCRIPTNAME:?}}"
  : "${baseid:=$(user_script_mkvid "${base:?}")}"

  # Get instance vars
  for var in name version shortdescr
  do
    var_=${baseid}_$var;
    test -z "${!var_:-}"  || eval "script_$var=\"${!var_}\""
  done
  : "${script_name:="$user_script_name:$SCRIPTNAME"}"
  : "${script_shortdescr:="User-script '$SCRIPTNAME' has no description. "}"

  # Get inherited vars
  for var in maincmds
  do
    for _baseid in $(${user_script_bases:-user_script_ bases} && echo $script_bases)
    do
      var_=${_baseid}_$var;
      test -n "${!var_:-}" || continue
      eval "script_$var=\"$_\""
      continue 2
    done
  done

  local SCRIPTNAME_ext=${SCRIPT_BASEEXT:-}
  : "${script_src:="$SCRIPTNAME$SCRIPTNAME_ext"}"
  test "$script_src" = user-script.sh || script_src="$script_src user-script.sh"
  # TODO: write us_load function ${script_lib:=user-script.lib.sh}
  script_lib=
}

script_cmdid ()
{
  script_cmd="${1:?}"
  script_cmdname="${script_cmd##*/}"
  script_cmdname="${script_cmdname%% *}"
  script_cmdid=$(user_script_mkvid "$script_cmd")
  test -z "${script_cmdals:-}" || {
      script_cmdalsid=$(user_script_mkvid "$script_cmdals")
    }
}

# Turn declaration into pretty print using sed
script_debug_arr () # ~ <Array-var> # Pretty print array
{
  test 1 -eq $# || return ${_E_MA:?}
  if_ok "$(declare -p ${1:?})" &&
      <<< "Array '${_:11}" sed "s/=(\[/':\\n\\t/
s/\" \[/\\n\\t/g
s/]=\"/\\t/g
s/\")//g
"
}

script_debug_class_arr () # ~ <key> [<Class>] # Pretty print Class array
{
  test 0 -lt $# -a 2 -ge $# || return ${_E_MA:?}
  script_debug_arr "${2:-Class}__${1:?}"
}

script_debug_libs () # ~ # List shell libraries loaded and load/init states
{
  echo "lib_loaded: $lib_loaded"
  if_ok "
$( lib_uc_hook pairs _lib_loaded | sort | sed 's/^/   /' )
lib_init:
$( lib_uc_hook pairs _lib_init | sort | sed 's/^/   /' )
" &&
  stderr echo "$_"
}

# Handle env setup (vars & sources) for script-entry. Executes first existing
# loadenv hook, unless it returns status E:not-found then it continues on to
# the next doenv hook on script-bases.
script_doenv () # ~ <Action <argv...>>
{
  script_baseenv &&
  script_cmdid "${1:?}" || return
  local _baseid stat
  for _baseid in $(${user_script_bases:-user_script_ bases} && echo $script_bases)
  do
    ! sh_fun "$_baseid"_loadenv || {
      ! us_debug || $LOG info :script:doenv "Loadenv" "$_baseid"
      "$_baseid"_loadenv "$@" || {
        test ${_E_not_found:?} -eq $? && continue ||
          $LOG error :script:doenv "During loadenv" "E$_:$_baseid" $_ ||
            return
      }
    }
  done
  script_cmdfun=${script_cmdname//-/_}
  # prefer to use most specific name, fallback to unprefixed handler function
  ! sh_fun "${baseid}_${script_cmdfun}" || script_cmdfun="$_"
  sh_fun "$script_cmdfun" || {
    $LOG error : "No such function" "$script_cmdfun"
    set -- $SCRIPTNAME usage -- "$script_cmd" "$@"
    user_script_load "$@" || return
    script_cmdfun=user_script_usage
  }
}

script_edit () # ~ # Invoke $EDITOR on script source(s)
{
  #test $# -gt 0 || set -- $script_src $script_lib
  "$EDITOR" "$0" "$@"
}

# Check if given argument equals zeroth argument.
# Unlike when calling script-name, this will not pollute the environment.
script_isrunning () # [SCRIPTNAME] ~ <Scriptname> [<Name-ext>]# argument matches zeroth argument
{
  test $# -ge 1 -a $# -le 2 || return ${_E_GAE:-3}
  test $# -eq 2 && {
    SCRIPT_BASEEXT="${2:?}"
  }
  script_name &&
      test "${SCRIPTNAME:?Expected SCRIPTNAME after script_name}" = "$1" || {
      test $# -lt 2 || unset SCRIPT_BASEEXT
      unset SCRIPTNAME; return 1
  }
}

script_name () # ~ <Command-name> # Set SCRIPTNAME env based on current $0
{
  : "${SCRIPTNAME:="$(basename -- "$0" ${SCRIPT_BASEEXT:-})"}"
}

# Undo env setup for script-entry (inverse of script-doenv)
script_unenv ()
{
  ! sh_fun "${baseid}"_unload || {
    "${baseid}"_unload || {
      $LOG warn ":user-script:unenv($baseid)" "Failure during unload" E$?
    }
  }

  local cmdstat=${script_cmdstat:-0}

  unset script{name,_{baseext,cmd{als,def,id,alsid,stat},defcmd}} base{,id}

  # FIXME: switch using sh-mode helper
  set +e
  # XXX: test "$IS_BASH" = 1 -a "$IS_BASH_SH" != 1 && set +uo pipefail
  test -z "${BASH_VERSION:-}" || set +uo pipefail
  test -z "${DEBUGSH:-}" || set +x

  return ${cmdstat:?}
  #test 0 -eq "$cmdstat" && return
  #case "$cmdstat" in
  #  ( ${_E_fail:?} | ${_E_syntax:?} | ${_E_todo:?}
  #return ${_E_error:?}
}


## U-s functions

# Helper to select/invoke handler specific to currently invoked user-script,
# XXX
user_script_ () # ~ <Hook-name> [<Hook-args...>]
{
  : "${base:=${SCRIPTNAME:?}}"
  : "${baseid:=$(user_script_mkvid "${base:?}")}"
  sh_fun ${baseid}_${1//-/_} || : user_script_${1//-/_}
  "$_" "${@:2}"
}

user_script_aliases () # ~ [<Name-globs...>] # List handlers with aliases
{
  # Match given function name globs, or set fairly liberal regex
  test $# -eq 0 && {
    set -- "[A-Za-z_:-][A-Za-z0-9_:-]*"
  } || {
    set -- "$(grep_or "$*")"
  }

  local bid fun vid
  user_script_aliases_raw | grep "\<$1\>" | {

    # Handle output formatting
    test -n "${u_s_env_fmt:-}" || {
      test ! -t 1 || u_s_env_fmt=pretty
    }
    case "${u_s_env_fmt:-plain}" in
        ( pretty ) grep -v '^#' | sort | column -s ':' -t ;;
        ( plain ) cat ;;
    esac
  }
}

user_script_aliases_raw ()
{
  for bid in $(${user_script_bases:-user_script_ bases} && echo $script_bases)
  do
    for h in ${user_script_defarg:-defarg}
    do
      sh_fun "${bid}_$h" && fun=${bid}_$h || {
        sh_fun "$h" && fun=$h || continue
      }
      echo "# $fun"
      case "${out_fmt:-}" in

          raw ) sh_type_esacs_als $fun ;;

          * )
              sh_type_esacs_als $fun | sed '
                      s/ set -- \([^ ]*\) .*$/ set -- \1/g
                      s/ *) .* set -- /: /g
                      s/^ *//g
                      s/ *| */, /g
                      s/"//g
                  '
            ;;
      esac
    done
  done
}

# Script bases has bit of a chicken-and-the-egg problem, so the script-name
# is used to select the initial function that resolves the current sequence.
# (See user-script- bases).
#
# Getting all groups involves sourcing of scripts/libs that contain definitions
# for bases that are included, but this implementation does not do that so
# it can be used inside $() substitutions. The script-bases value can be pre-
# seeded this way too. This adds either the current scriptname and all the
# groups it is in, or whatever is given as arguments (and their groups). But
# the set may be incomplete if not all their definitions are pre-sourced.
user_script_bases () # ~ [script-bases] ~ <keys...>
{
  test $# -gt 0 || {
    : "${base:=${SCRIPTNAME:?}}"
    : "${baseid:=$(user_script_mkvid "${base:?}")}"
    set -- $base
  }

  local _baseid
  while test $# -gt 0
  do
    _baseid=${1//[:.-]/_}
    script_bases="${script_bases:-}${script_bases:+ }$_baseid"
    shift
    # Repeat loop while key has group attribute
    : ${_baseid}__grp
    test -z "${!_:-}" || set -- "$_" "$@"
  done

  # Append user-script if it is not the last group?
  #test "$baseid" = user_script ||
  # XXX: or if only one element same as scriptname id?
  test "$script_bases" != "$baseid" || script_bases="$script_bases user_script"
}

user_script_cli ()
{
  case "${1:?}" in
    ( bases )
        $LOG info : preseed-bases "${script_bases:-(unset)}"
        ( ${user_script_bases:-user_script_ bases} "${@:2}" &&
            echo $script_bases
        )
      ;;
    ( * ) $LOG error :cli "?" "$1" 127 ;;
  esac
}

# TODO: commands differs from handlers in that it lists maincmds and aliases
user_script_commands () # ~ # Resolve aliases and list command handlers
{
  # FIXME: maincmds list are not functions, use aliases to resolve handler names
  test $# -gt 0 || set -- $script_maincmds
  user_script_resolve_aliases ||
      $LOG error :commands "Resolving aliases" "E$?:$*" $? || return
  user_script_handlers "$@" ||
      $LOG error :commands "Resolving handlers" "E$?:$*" $?
}

# Output argv line after doing 'default' stuff. Because these script snippets
# have to change the argv of the function, it is not possible to move them to
# subroutines. And user-script implementations will have to copy these scripts,
# and follow changes to it.
user_script_defarg ()
{
  local rawcmd="${1:-}" defcmd=

  # Track default command, and allow it to be an alias
  user_script_defcmd "$@" || set -- $script_defcmd

  # Resolve aliases
  case "$1" in

      # XXX: ( a|all ) shift && set -- user_scripts_all ;;

      ( bases|--list-script-bases ) shift; set -- user_script_ cli bases "$@" ;;

      # Every good citizen on the executable lookup PATH should have these
      ( "-?"|-h|help )
            test $# -eq 0 || shift; set -- user_script_help "$@" ;;
      ( --help|long-help )
            test $# -eq 0 || shift; set -- user_script_longhelp "$@" ;;
      ( -V|--version|version )
            test $# -eq 0 || shift; set -- script_version "$@" ;;

      ( --aliases|aliases )
            test $# -eq 0 || shift; set -- user_script_aliases "$@" ;;
      ( --aliases-raw)
            test $# -eq 0 || shift; set -- user_script_aliases_raw "$@" ;;

      ( --handlers|handlers ) # Display all potential handlers
            test $# -eq 0 || shift; set -- user_script_handlers "$@" ;;

      ( --commands|commands ) # ....
            test $# -eq 0 || shift; set -- user_script_commands "$@" ;;

      ( --env|variables )
            test $# -eq 0 || shift; set -- user_script_envvars "$@" ;;

  esac

  # Hook-in more for current user-script or other bases
  # Script needs to be sourced or inlined from file to be able to modify
  # current arguments.
  local bid fun xtra_defarg
  for bid in $(${user_script_bases:-user_script_ bases} && echo $script_bases)
  do
    for h in ${user_script_defarg:-defarg}
    do
      sh_fun "${bid}_${h}" || {
        continue
      }
      # Be careful not to recurse to current function
      test "$h" != defarg -o "$bid" != user_script || continue
      eval "$(sh_type_fun_body $bid"_"$h)" || return
    done
  done

  # Print everything using appropiate quoting
  argv_dump "$@"
  exit $?

  # Print defs for some core vars for eval as well
  user_script_defcmdenv "$@"
}

user_script_defcmd ()
{
  true "${script_defcmd:="usage"}"
  test $# -gt 0 && defcmd=0 || {
    defcmd=1
    return 1
  }
}

user_script_defcmdenv ()
{
  test "$1" = "$rawcmd" \
      && printf "; script_cmdals=" \
      || printf "; script_cmdals='%s'" "$rawcmd"
  printf "; script_defcmd='%s'" "$script_defcmd"
  printf "; script_cmddef='%s'" "$defcmd"
}

user_script_envvars () # ~ # Grep env vars from loadenv
{
  local bid h
  for bid in $(${user_script_bases:-user_script_ bases} && echo $script_bases)
  do
    for h in loadenv ${script_xtra_envvars:-defaults}
    do
      sh_fun "${bid}_$h" || continue
      echo "# ${bid}_$h"
      type "${bid}_$h" | grep -Eo -e '\${[A-Z_]+:=.*}' -e '[A-Z_]+=[^;]+' |
            sed '
                  s/\([^:]\)=/\1\t=\t/g
                  s/\${\(.*\)}$/\1/g
                  s/:=/\t?=\t/g
              '
      true
    done
  done | {

    # Handle output formatting
    test -n "${u_s_env_fmt:-}" || {
      test ! -t 1 || u_s_env_fmt=pretty
    }
    case "${u_s_env_fmt:-}" in
        ( pretty ) grep -v '^#' | sort | column -s $'\t' -t ;;
        ( ""|plain ) cat ;;
    esac
  }
}

# FIXME: fixup before calling lib-init shell-uc
user_script_fix_shell_name ()
{
  PID_CMD=$(ps -q $$ -o command= | cut -d ' ' -f 1)
  test "${SHELL_NAME:=$(basename -- "$SHELL")}" = "$PID_CMD" || {
    test "$PID_CMD" = /bin/sh && {
      ${LOG:?} note "" "$SHELL_NAME running in special sh-mode"
    }
    # I'm relying on these in shell lib but I keep getting them in the exports
    # somehow
    SHELL=
    SHELL_NAME=
    #|| {
    #  $LOG warn ":env" "Reset SHELL to process exec name '$PID_CMD'" "$SHELL_NAME != $PID_CMD"
    #  #SHELL_NAME=$(basename "$PID_CMD")
    #  #SHELL=$PID_CMD
    #}
  }
}

# Transform glob to regex and invoke script-listfun for libs and other source
# files. This turns on script-listfun flag h by default.
user_script_handlers () # ~ [<Name-globs...>] # Grep function defs from main script
{
  test $# -eq 0 && set -- "$(user_script_mkvid)" || set -- "$(grep_or "$@")"

  # NOTE: some shell allow all kinds of characters in functions.
  # sometimes I define scripts as /bin/bash and use '-', maybe ':'.

  local name slf_h=${slf_h:-1}

  for name in $script_lib
  do
    $LOG debug :handlers "Listing from lib" "$name:$1"
    script_listfun "$name" "$1" || true
  done

  for name in $script_src
  do
    $LOG debug :handlers "Listing from source" "$name:$(command -v "$name"):$1"
    script_listfun "$(command -v "$name")" "$1" || true
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
  local _baseid

  #for _baseid in $(${user_script_bases:-user_script_ bases} && echo $script_bases)
  #do
  #  ! sh_fun "${_baseid}"_usage || break
  #done
  #"${_baseid}"_usage "$@"

  user_script_ usage "$@" || return

  test $# -gt 0 -o "${longhelp:-0}" -eq 0 || {

    # Add env-vars block, if there is one
    test "${longhelp:-0}" -eq 0 || {
      envvars=$( user_script_envvars | grep -v '^#' | sed 's/^/\t/' )
      test -z "$envvars" ||
          printf '\nEnv vars:\n%s\n\n' "$envvars"
    }
  }
}

# init-required-libs
# Temporary helper to load and initialize given libraries and prerequisites,
# and run init hooks. Libs should use lib-require from load or init hook to
# indicated the prerequisites.
# XXX: lib-init is protected against recursion.
#
user_script_initlibs () # ~ <Required-libs...>
{
  local pending
  lib_require "$@" ||
    $LOG error :us-initlibs "Failure loading libs" "E$?:$*" $? || return

  set -- $(user_script_initlibs__needsinit $lib_loaded)
  while true
  do
    # remove libs that have <libid>_init=0 ie. are init OK
    set -- $(user_script_initlibs__initialized "$@")
    test $# -gt 0 || break
    pending=$#

    $LOG info :us-initlibs "Initializing" "[:$#]:$*"
    INIT_LOG=$LOG lib_init "$@" || {
      test ${_E_retry:-198} -eq $? && {
          set -- $(user_script_initlibs__initialized "$@")
          test $pending -gt $# || {
            set -- "${@:2}" "$1"
          }
          #  $LOG error :us-initlibs "Unhandled next" "[:$#]:$*" 1 || return
          continue
        } ||
          $LOG error :us-initlibs "Failure initializing libs" "E$_:$lib_loaded" $_ || return
      }
  done
}
user_script_initlibs__needsinit ()
{
  for lib in "$@"
  do
    : "${lib//[^A-Za-z0-9_]/_}_lib__init"
    ! sh_fun "$_" || echo "$lib"
  done
}
user_script_initlibs__initialized ()
{
  for lib in "$@"
  do
    : "${lib//[^A-Za-z0-9_]/_}_lib_init"
    test 0 = "${!_:-}" || echo "$lib"
  done
}

# TODO: deprecate
user_script_libload ()
{
  test $# -gt 0 || return
  while test $# -gt 0
  do
    . "$1" || return
    script_lib=${script_lib:-}${script_lib:+ }$1
    shift
  done
}

# Traverse <script-bases>, looking for <base>-<name> using the specified
# handler. Keep prefixing arguments with <node-group> while set after running
# each handler.
#
# myscript-myname
#
# script-loadenv
# user-script-loadenv
#
# '<Node>[:.-]<Node-id>'
#
# <script-name>/<command-name>:grp sys
# <base>/sys:libs sys-htd

# Travel to root from name, evoking handler for every node.
# XXX: user_script_baseless=true must be set for exception?
user_script_node_lookup () # ~ <Handler> <Name> [<Groups...>]
{
  local node group _base handler=${1:?} script_bases
  sh_fun "$handler" || handler=user_script_node_${1//[:.-]/_}
  sh_fun "$handler" || {
    TODO "$1" || return
  }
  shift
  script_bases=$(${user_script_bases:-user_script_ bases} && echo $script_bases)
  while test $# -gt 0
  do
    node=${1:?} nodeid=${1//[:.-]/_}
    fnmatch "* $nodeid *" " $script_bases " && root=true || root=false
    shift

    # If node is a leaf in the primary base does not need to bear prefix,
    # and if it is a base itself that would not make any sense. XXX: If node is
    # a base it could still have another group that is not in bases.
    ! ${user_script_baseless:-false} &&
    ! $root || {
      # Exception for leaf-most name, does not have to use base prefix
      $handler ${node:?} || return
      test -z "${group:-}" || {
          shift
          set -- $group "$@"
          continue
      }
    }
    for _base in $script_bases
    do
      $handler ${_base:?}-${node:?} || return
      test -n "${group:-}" || continue
      set -- $_ "$@"
      break
    done
  done
}

# Helper functions that groups several setup script parts, used for static
# init, loadenv, etc.
#
#   defarg: Load/init user-script base. Call before using defarg etc.
#   groups: Scan for [<base>_]<script-part>__{grp,libs,hooks}
#   usage: Load/init libs for usage
#
user_script_load () # ~ <Actions...>
{
  test $# -gt 0 || set -- defarg
  while test $# -gt 0
  do
    ! uc_debug ||
        $LOG info :user-script:load "Running load action" "$1"
    case "${1:?}" in

      ( groups )
          local name=${script_part:-$script_cmd} libs ctx \
            lk=${lk:-}:user-script:load[group]
          ctx="$name:$(${user_script_bases:-user_script_ bases} && echo $script_bases)"
          $LOG notice "$lk" "Lookup grp/libs/hooks within bases" "$ctx"
          user_script_node_lookup attr-libs "$name" &&
          user_script_node_lookup attr-hooks "$name" || return
          test -z "${libs:-}" && {
            test -z "${hooks:-}" && {
              $LOG warn "$lk" "No grp/libs or hooks for user-script sub-command" "$ctx"
              return ${_E_next:?}
            }
          } || {
            $LOG notice "$lk" "Initializing libs for group" "$name:$libs"
            user_script_initlibs $libs ||
              $LOG error "$lk" "Initializing libs for group" "E$?:$name:$libs" $?
          }
          test -z "${hooks:-}" && return
          local hook
          for hook in $hooks
          do "$hook" || $LOG error "$lk" "Failed in hook" "E$?:$hook" $? ||
            return
          done
        ;;

        # FIXME: probably want to use groups ehre as well
      ( defarg )
        lib_load user-script shell-uc str argv us &&
        lib_init shell-uc ;;

      ( usage )
        lib_load user-script str-htd shell-uc us &&
        lib_init shell-uc ;;

      ( help ) set -- "" usage ;;
      ( -- ) break ;;

      ( bash-uc ) lib_load bash-uc && lib_init bash-uc ;;

      ( self-lib ) user_script_initlibs ${script_name} ;;

      ( * ) $LOG error :user-script:load "No such load action" "$1" \
          ${_E_not_found:?} ;;
    esac ||
        $LOG error :user-script:load "In load action" "E$?:$1" $? || return
    shift
  done
}

# Default loadenv for user-script, run at the end of doenv just before
# deferring to handler.
user_script_loadenv ()
{
  : "${US_BIN:="$HOME/bin"}"
  : "${PROJECT:="$HOME/project"}"
  : "${U_S:="$PROJECT/user-scripts"}"
  : "${LOG:="$U_S/tools/sh/log.sh"}"

  # See std-uc.lib
  : "${_E_fail:=1}"
  : "${_E_script:=2}"
  : "${_E_user:=3}"

  : "${_E_nsk:=67}"
  #: "${_E_nsa:=68}"
  #: "${_E_cont:=100}"
  : "${_E_recursion:=111}" # unwanted recursion detected

  : "${_E_NF:=124}" # no-file/no-such-file(set): file missing or nullglob
  : "${_E_todo:=125}" # impl. missing
  : "${_E_not_exec:=126}" # NEXEC not-an-executable
  : "${_E_not_found:=127}" # NSFC no-such-file-or-command
  # 128+ is mapped for signals (see trap -l)
  # on debian linux last mapped number is 192: RTMAX signal
  : "${_E_GAE:=193}" # generic-argument-error/exception
  : "${_E_MA:=194}" # missing-arguments
  : "${_E_continue:=195}" # fail but keep going
  : "${_E_next:=196}"  # Try next alternative
  : "${_E_break:=197}" # success; last step, finish batch, ie. stop loop now and wrap-up
  : "${_E_retry:=198}" # failed, but can or must reinvoke
  : "${_E_limit:=199}" # generic value/param OOB error?

  TODO () { test -z "$*" || stderr echo "To-Do: $*"; return ${_E_todo:?}; }

  error () { $LOG error : "$1" "E$2" ${2:?}; }
  warn () { $LOG warn : "$1" "E$2" ${2:?}; }

  test -d "$US_BIN" || {
    $LOG warn :loadenv "Expected US-BIN (ignored)" "$US_BIN"
  }
  user_script_fix_shell_name
  user_script_shell_mode
  # XXX: Load bash-uc because it sets errexit trap, should cleanup above shell-mode
  test "$SCRIPTNAME" != user-script.sh && {
    user_script_load bash-uc || return
  } || {
    user_script_load "${script_cmdals:-$script_cmd}" bash-uc
  } &&
  user_script_loaded=1
}

user_script_longhelp () # ~ [<Name>]
{
  longhelp=1 user_script_help "$@"
}

# XXX: cannot define patterns dynamically without eval?
user_script_mkvid ()
{
  test $# -le 1 || return ${_E_GAE:-3}
  test $# -eq 0 && {
    echo "[A-Za-z_${US_EXTRA_CHAR:-}][A-Za-z0-9_${US_EXTRA_CHAR:-}]*"
    return
  }
  #echo "${1//[A-Za-z_${US_EXTRA_CHAR:-}][A-Za-z0-9_${US_EXTRA_CHAR:-}]*}"
  echo "${1//[^A-Za-z0-9_]/_}"
}

user_script_node_attr_grp ()
{
  : "${1//[:.-]/_}__grp"
  group="${!_:-}"
  ${lookup_quiet:-false} || test -z "$group" || echo "$group"
}

user_script_node_attr_libs ()
{
  : "${1//[:.-]/_}__libs"
  test -z "${!_:-}" || {
    #$LOG debug :attr:libs "Libs:" "$_"
    libs=${libs:-}${libs:+ }${_//,/ }
  }
  lookup_quiet=true user_script_node_attr_grp "$1"
}

user_script_node_attr_hooks ()
{
  : "${1//[:.-]/_}__hooks"
  test -z "${!_:-}" || {
    # TODO: maybe resolve hooks given current node/groups
    #$LOG debug :atr:hooks "Hooks:" "$_"
    hooks=${hooks:-}${hooks:+ }${_//,/ }
  }
  lookup_quiet=true user_script_node_attr_grp "$1"
}

user_script_resolve_alias () # ~ <Name> #
{
  echo "$us_aliases" | {
      while read -r handler aliases
      do
        test "$handler" != "$handle" && {
            case " $aliases " in
                ( *" $handle "* ) echo $handler ; return ;;
                ( * ) continue ;;
            esac
        } || {
          echo $handler
          return
        }
      done
      return 3
  }
}

user_script_resolve_aliases () # ~ <Handlers...> # List aliases for given names
{
  for handle in "$@"
  do
      {
          user_script_resolve_alias "$handle" || echo
      } | sed "s#^#$handle #"
  done
}

user_script_resolve_alias () # ~ <Name> # Give aliases for handler
{
  echo "$us_aliases" | {
      while read -r handler aliases
      do
        test "$handler" != "$handle" && {
            case " $aliases " in
                ( *" $handle "* ) echo $aliases ; return ;;
                ( * ) continue ;;
            esac
        } || {
          echo $aliases ; return
        }
      done
      return 3
    }
}

user_script_resolve_handlers () # ~ <Handlers...> # List handlers for given names
{
  for handle in "$@"
  do
    echo "$us_aliases" | {
        while read -r handler aliases
        do
          test "$handler" = "$handle" && {
              echo $handler
          } || {
              case " $aliases " in
                  ( *" $handle "* ) echo $handler ; break ;;
                  ( * ) false ;;
              esac
          }
        done
      } || echo $handle
  done
}

user_script_shell_mode ()
{
  test -n "${user_script_shell_mode:-}" && return
  user_script_shell_mode=0

  # XXX: see bash-uc init hook

  #test -z "${DEBUGSH:-}" || set -x

  #"${U_S:?}"/tools/sh/parts/sh-mode.sh &&
  #test "${DEBUG:-0}" = "0" && {
  #    sh_mode strict || return
  #  } || {
  #    sh_mode strict dev || return
  #  }

  #test -z "${BASH_VERSION:-}" || {
  ## XXX: test "$IS_BASH" = 1 -a "$IS_BASH_SH" != 1 && {

  #  set -u # Treat unset variables as an error when substituting. (same as nounset)
  #  set -o pipefail #

  #  test -z "${DEBUG:-}" || {

  #    set -h # Remember the location of commands as they are looked up. (same as hashall)
  #    set -E # If set, the ERR trap is inherited by shell functions.
  #    set -T
  #    set -e
  #    shopt -s extdebug
  #  }
  #}
  test -z "${DEBUG:-}" ||
    : "${BASH_VERSION:?"Not sure how to do debug"}"

  test -z "${ALIASES:-}" || {
    : "${BASH_VERSION:?"Not sure how to do aliases"}"

    # Use shell aliases and templates to cut down on boilerplate for some
    # user-scripts.
    # This gives a sort-of macro-like functionality for shell scripts that is
    # useful in some contexts.
    shopt -s expand_aliases &&

    us_shell_alsdefs &&
    user_script_alsdefs ||
        $LOG error : "Loading aliases" E$? $? || return
  }

  user_script_shell_mode=1
}

# Display description how to evoke command or handler
user_script_usage () # ~
{
  local short=0 slf_l

  test $# -eq 0 && {
    short=1
    slf_l=0
    set -- $script_maincmds
    printf 'Usage:\n\t%s <Command <Arg...>>\n' "$base"
  } || {
    slf_l=1
    printf 'Usage:\n'
  }

  lib_load str-htd || return

  # Resolve handler (if alias) and output formatted spec
  local us_aliases alias_sed handlers
  test $slf_l -eq 0 && {
      user_script_usage_handlers "$@" || {
        $LOG error :usage "handlers for" "E$?:$*" $? || return
      }
    } || {
      user_script_usage_handlers "$1" || true
    }

  # XXX: could jsut use bash extdebug instead of script-{src,lib}
  # however these all have to be loaded first, creating a chicken and the egg
  # problem
  # TODO func-comment Needs abit of polishing. and be moved to use for other
  # functions as well
  test -n "$handlers" || {
    $LOG error :user-script:usage "No handler found" "$*"
    return 1

    "${baseid}"_loadenv all || return
    user_script_usage_ext "$1" || return
    echo "Shell Function at $(basename "$fun_src"):$fun_ln:"
    script_listfun $fun_src "$handlers"
    #. $U_S/src/sh/lib/os.lib.sh
    . $U_S/src/sh/lib/src.lib.sh
    func_comment "$handlers" "$fun_src"
  }

  # Gather functions again, look for choice-esacs
  local sub_funs actions
  test $slf_l -eq 0 && {
      user_script_usage_choices "$handlers" || true
    } || {
      user_script_usage_choices "$handlers" "${2:-}"
    }

  test $short -eq 1 && {
    test -z "${script_defcmd-}" ||
      printf '\t%s (%s)\n' "$base" "$script_defcmd"
    printf '\n%s\n' "${script_shortdescr:-(no-shortdescr)}"
  } || {
    true # XXX: func comments printf '%s\n\n' "$_usage"
  }
}

user_script_usage_choices () # ~ <Handler> [<Choice>]
{
  sub_funs=$( slf_t=1 slf_h=0 user_script_handlers ${1:?} |
      while IFS=$'\t' read -r fun_name fun_spec fun_descr
      do
        fnmatch "* ?y? *" " $fun_spec " || continue
        echo "$fun_name"
      done)
  test -n "$sub_funs" || {
    $LOG debug "" "No choice specs" "$1"
    return 0
  }

  # Always use long-help format if we're selecting a particular choice (set)
  test -n "${2:-}" -o ${longhelp:-0} -eq  1 && {

    test -z "${2:-}" && {
       actions=$( for fun_name in $sub_funs
         do
           sh_type_esacs_tab $fun_name
         done |
             sed 's/\t/\t$ /' | column -c2 -s $'\t' -t )
    } || {

       actions=$( for fun_name in $sub_funs
         do
           sh_type_esacs_tab $fun_name
         done |
             grep '\(^\|| \)'"${2:-".*"}"'\( |\|'$'\t''\)' |
         while IFS=$'\t' read -r alias_case alias_exec
         do
           alias_cmd=${alias_exec// *}
           test -n "$alias_cmd" || {
             $LOG error "" "No handler found" "action:$2 case:$alias_case"
             continue
           }
           echo -e "$alias_case\t$ $alias_cmd"
           user_script_usage "$alias_cmd" | tail -n +3 | sed 's/^/ \t \t/'
         done | column -c2 -s $'\t' -t )
    }

  } || {
    actions=$(for fun_name in $sub_funs
        do sh_type_esacs_choices $fun_name
        done | grep -v '^\*$' )
  }
  test -n "$actions" || {
    $LOG error "" "Cannot get choices" "fun:${1:?}"
    return 1
  }
  test -n "${2:-}" && {
    printf "\nChoice '%s':\n" "$2"
  } || {
    printf "\nAction choices:\n"
  }
  echo "$actions" | sed 's/^/\t/'
}

user_script_usage_ext ()
{
  local h=$1 fun=${1//-/_} fun_def

  shopt -s extdebug
  fun_def=$(declare -F "$fun") || {
    $LOG error "" "No such type loaded" "fun?:$fun"
    return 1
  }

  fun_src=${fun_def//* }
  fun_def=${fun_def% *}
  fun_ln=${fun_def//* }

  script_lib=${script_lib:-}${script_lib:+ }$fun_src
  handlers=$fun
}

user_script_fetch_handlers ()
{
  us_aliases=$(user_script_aliases "$@" |
        sed 's/^\(.*\): \(.*\)$/\2 \1/' | tr -d ',' )
  alias_sed=$( while read -r handler aliases
          do
              printf 's/^\<%s\>/( %s | & )/\n' "$handler" "${aliases// / | }"
          done \
        <<< "$us_aliases"
      )
  handlers=$(user_script_resolve_handlers "$@" | remove_dupes | lines_to_words)
}

# Output formatted help specs for one or more handlers.
user_script_usage_handlers ()
{
  user_script_fetch_handlers "$@" || return

  # FIXME:
  # Do any loading required for handler, so script-src/script-lib is set
  #! sh_fun "${baseid}"_loadenv || {
  #  "${baseid}"_loadenv $handlers || {
  #      $LOG error :handlers "Loadenv error" "E$?" $? || return
  #  }
  #}

  # Output handle name(s) with 'spec' and short descr.
  slf_h=1 user_script_handlers $handlers | sed "$alias_sed" | sed "
        s/^\t/\t\t/
        s/^[^\t]/\t$base &/
    "
}

script_version () # ~ # Output {name,version} from script-baseenv
{
  echo "${script_name:?}/${script_version:-null}"
}

# Use alsdefs set to cut down on small multiline boilerplate bits and reduce
# those idiomatic script parts to oneliners, tied with re-usable patterns.
# See us-shell-alsdefs.
#
# This defines the basic set provided and used? by user-scripts,
# and doubles as a oneliner for user-scripts to add their own.
user_script_alsdefs ()
{
    # alias-name   alsdef-key     input-1,2,3...  --
  us_shell_alias_defs \
  \
    sa_a1_act_lk   l-argv1-lk   act :-\$actdef ""         \${lkn:-\$act} -- \
    sa_a1_act_lk_2 l-argv1-lk   act :-\$actdef :-\$base:\$act  "" -- \
  \
    sa_a1_d_lk     de-argv1-lk      \$_1def    :?         \${lkn:-\$1} -- \
    sa_a1_d_lk_b   de-argv1-lk      \$_1def    :-\$base   \${lkn:-\$1} -- \
    sa_a1_d_nlk    de-argv1-lk      \$_1def    :?         \${lkn:-\${n:?}:\$1} -- \
  \
    sa_E_nschc     err-u-nsk   \$lk "No such choice" "" 67 -- \
    sa_E_nsact     err-u-nsk   \$lk "No such action" \$act 67 -- \
  \
    "$@"
}

# Shell aliases can be useful, except when used as macro then they don't even
# have some variable expansion. But if we escape their definitions for eval,
# we can still declare new specific aliases from re-usable patterns.
#
# See us-shell-alias-def.
us_shell_alsdefs ()
{
  # XXX: note the us vs uc. ATM not sure I really want these 'expansions' in US.
  declare -g -A uc_shell_alsdefs=()

  # Some current patterns. Probably want to move to compose.

  # Take first argument and set to variable, and update LOG scope
  # This can both do optional or required, if $2 uses :? it will fail on empty
  # and unset.
  uc_shell_alsdefs[l-argv1-lk]='
    local ${1:?}=\${1${2:?}}
    test \$# -eq 0 || shift
    local lk=\"\${lk${3:-":-\$base"}}${4:+:}${4:-}\"
  '

  uc_shell_alsdefs[d-argv1-lk]='
    test -n "\${1:-}" || {
      test $# -eq 0 || shift; set -- \"${1:?}\" "$@";
    }
    local lk=\"\${lk${2:-:-\$base}}${3:+:}${3:-}\"
  '

  uc_shell_alsdefs[de-argv1-lk]='
    test \$# -gt 0 || set -- \"${1:?}\"
    local lk=\"\${lk${2:-:-\$base}}${3:+:}${3:-}\"
  '

  # Take first argument and set to variable, and test for block device.
  uc_shell_alsdefs[l-argv1-bdev]='
    local ${1:?}=\${1${2:-":?"}}
    shift
    test -b \"\$${1:?}\" || {
      \$LOG warn \"${3:-\$base}\" \"Block device expected\" \"\" \$?
      return ${4:-3}
    }
  '

  # Argument helpers

  # Move to next sequence in arguments or return if empty
  uc_shell_alsdefs[argv-next-seq]='
      test \$# -eq 0 && return ${1:-0}
      while test \$# -gt 0 -a \"\${1:-}\" != \"--\"; do shift || return; done
      test \$# -eq 0 && return ${2:-0}
      shift
  '

  # Generic error+return
  uc_shell_alsdefs[err-u-nsk]='
    \$LOG error \"${1:-\$lk}\" \"${2:-"No such key/selection"}\" \"${3:-\$1}\";
    return ${4:-1}
  '
}

# NOTE: to be able to use us_shell_alias_defs, make sure you always call with
# fixed argument lengths to your templates.
us_shell_alias_def ()
{
  local als_name=${1:?} als_tpl=${2:?}
  shift 2
  eval "alias $als_name=\"${uc_shell_alsdefs[$als_tpl]}\"" ||
      $LOG error : "Evaluating template for alias" "E$?:$als_name:$als_tpl" $?
}

# Call us-shell-alias-def for each argv sequence (separated by '--')
# XXX: a better version would use arrays I guess
us_shell_alias_defs ()
{
  while test $# -gt 0
  do
    { ${alsdef_override:-false} && {
        ! ${US_DEBUG:-${DEBUG:-false}} ||
            test "$(type -t "${1:?}")" != alias || {
              unalias $1
              $LOG info : "Overriding alsdef" "$1:$2"
            }
      } ||
        test "$(type -t "${1:?}")" != alias
    } && {
      us_shell_alias_def "$@" || return
      ! ${US_DEBUG:-${DEBUG:-false}} ||
          $LOG debug : "Defined alsdef" "$1:$2"
    } || {
      ! ${US_DEBUG:-${DEBUG:-false}} ||
          $LOG debug : "Skipped alsdef" "$1:$2"
    }
    shift 2
    while test "${1:-}" != "--"
    do test $# -gt 0 || return 0
      shift
    done
    shift
  done
}


## Other functions

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
stdmsg () # (e) ~ <Class> <Message> [<Context>]
{
  ${quiet:-false} && return
  true "${v:="${verbosity:-4}"}"
  case "${1:?}" in
      ( *"emerg" ) ;;
      ( *"alert" ) test "$v" -gt 0 || return 0 ;;
      ( *"crit" )  test "$v" -gt 1 || return 0 ;;
      ( *"err" )   test "$v" -gt 2 || return 0 ;;
      ( *"warn" )  test "$v" -gt 3 || return 0 ;;
      ( *"note" )  test "$v" -gt 4 || return 0 ;;
      ( *"info" )  test "$v" -gt 5 || return 0 ;;
      ( *"debug" ) test "$v" -gt 6 || return 0 ;;
  esac
  echo "${2:?}" >&2
}

stdstat () # ~ <Status-Int> <Status-Message> # Exit handler
{
  type sh_state_name >/dev/null 2>&1 &&
    stdmsg '*note' "$(sh_state_name "$1"): $2" ||
    stdmsg '*note' "Status was $1: $2"
  exit $1
}

us_debug ()
{
  ${US_DEBUG:-false}
}

# Lists name, spec and gist fields separated by tabs.
# Fun flag t turns off column formatting
# Fun flag h enables an alternative semi-readable help outline format
script_listfun () # (s) ~ [<Grep>] # Wrap grep for function declarations scan
{
  local script_src="${1:-"$(script_source)"}"
  shift 1
  fun_flags slf ht l
  grep "^$1 *() #" "$script_src" | {
    test $slf_h = 1 && {
      # Simple help format from fun-spec
      sed '
            s/ *() *# [][(){}a-zA-Z0-9=,_-]* *~ */ /g
            s/# \([^~].*\)/\n\t\1\n/g
          ' | {
                # Strip short usage descr
                test $slf_l = 1 && cat ||
                    grep -v -e '^'$'\t' -e '^$'
              }

    } || {

      # Turn into three tab-separated fields: name, spec, gist
      sed '
            s/ *() *//
            s/# \~ */#/
          ' | tr -s '#' '\t' | {
        test $slf_t = 1 && {
          cat
        } || {
          column -c3 -s "$(printf '\t')" -t | sed 's/^/\t/'
        }
      }
    }
  }
}

#user_script_sh__grp=user-script
#{
#  user_script_bases >/dev/null
#  script_bases="${script_bases:?} user_script_sh"
#  echo "$script_bases"
#}

user_script_sh_aliasargv ()
{
  case "$1" in

      ( find|--find-user-scripts ) shift; set -- user_script_find "$@" ;;

      # FIXME: sh-type-esacs-als currently does not match var ref in argv alias
      ( bases|--list-script-bases ) shift;
          shift; set -- user_script_ cli bases "$@" ;;

  esac
}

user_script_sh_loadenv ()
{
  : "${_E_next:=196}"

  script_part=user-script user_script_load groups ||
      test ${_E_next:?} -eq $? || return $_

  script_part=${1:?} user_script_load groups || {
      # E:next means no libs found for given group(s).
      test ${_E_next:?} -eq $? || return $_
    }
}

usage ()
{
  local failcmd ; test "${1-}" != "--" || { shift; failcmd="$*"; shift $#; }
  script_version "$@" >&2
  user_script_help "$@" >&2
  test -z "${failcmd-}" || {
    $LOG error ":usage" "No such command" "$failcmd"
    return 2
  }
  # Exit non-zero unless command was given
  test "${script_cmddef-}" = "0"
}


# Main boilerplate (mostly useless except for testing this script)
# To list all user-script instances, see user-script.sh all.

test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"

! script_isrunning "user-script" .sh || {

  user_script_load || exit $?

  # Strip extension from SCRIPTNAME (and baseid)
  SCRIPT_BASEEXT=.sh
  # Default value used when argv is empty
  #script_defcmd=usage
  # Extra handlers for user-script-aliases to extract from
  user_script_defarg=defarg\ aliasargv
  script_bases=user_script_sh

  # Pre-parse arguments and reset argv: resolve aliased commands or sets default
  eval "set -- $(user_script_defarg "$@")"

  true "${US_EXTRA_CHAR:=:-}"

  # Execute argv and end shell
  script_run "$@" || exit
}

user_script_loaded=0
#
