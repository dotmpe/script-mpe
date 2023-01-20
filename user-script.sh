#!/bin/sh

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


# Execute when script is sourced, when given base matches SCRIPTNAME.
# If the handlers prefixes don't match the exec name, use
# base var to change that.
script_entry () # [script{name,_baseext},base] ~ <Scriptname> <Arg...>
{
  local SCRIPTNAME=${SCRIPTNAME:-}
  script_name || return
  if test "$SCRIPTNAME" = "$1"
  then
    user_script_shell_env || return
    shift
    script_doenv "$@" || return
    stdmsg '*debug' "Entering user-script $(script_version)"
    sh_fun "$1" || set -- usage -- "$@"
    "$@" || script_cmdstat=$?
    script_unenv || return
  fi
}


script_baseenv ()
{
  local vid var var_ _baseid
  mkvid "${base:="$SCRIPTNAME"}"; baseid=$vid

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
    for _baseid in $(${user_script_bases:-user_script_bases})
    do
      var_=${_baseid}_$var;
      test -n "${!var_:-}" || continue
      eval "script_$var=\"${!var_}\""
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
  script_cmd="$1"

  mkvid "$1"; script_cmdid=$vid
  test -z "$script_cmdals" || {
      mkvid "$script_cmdals"; script_cmdalsid=$vid
    }
}

# Handle env setup (vars & sources) for script-entry
script_doenv ()
{
  script_baseenv &&
  script_cmdid "$1" || return

  ! sh_fun "${baseid}"_loadenv || {
    "${baseid}"_loadenv || return
  }

  test -z "${DEBUGSH:-}" || set -x
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
  script_name && test "$SCRIPTNAME" = "$1"
}

# Undo env setup for script-entry (inverse of script-doenv)
script_unenv ()
{
  ! sh_fun "${baseid}"_unload || {
    "${baseid}"_unload || return
  }

  local cmdstat=${script_cmdstat:-0}

  unset script{name,_{baseext,cmd{als,def,id,alsid,stat},defcmd}} base{,id}

  set +e
  # XXX: test "$IS_BASH" = 1 -a "$IS_BASH_SH" != 1 && set +uo pipefail
  test -z "${BASH_VERSION:-}" || set +uo pipefail
  test -z "${DEBUGSH:-}" || set +x

  return $cmdstat
}

script_name ()
{
  : "${SCRIPTNAME:="$(basename -- "$0" ${SCRIPT_BASEEXT:-})"}"
}


## U-s functions

user_script_aliases () # ~ [<Name-globs...>] # List handlers with aliases
{
  # Match given function name globs, or set fairly liberal regex
  test $# -eq 0 && {
    set -- "[A-Za-z_:-][A-Za-z0-9_:-]*"
  } || {
    set -- "$(grep_or "$*")"
  }

  local bid fun
  for bid in $(${user_script_bases:-user_script_bases})
  do
    for h in ${script_xtra_defarg:-} defarg
    do
      sh_fun "${bid}_$h" && fun=${bid}_$h || {
        sh_fun "$h" && fun=$h || continue
      }
      echo "# $fun"
      sh_type_esacs_als $fun | sed '
              s/ set -- \([^ ]*\) .*$/ set -- \1/g
              s/ *) .* set -- /: /g
              s/^ *//g
              s/ *| */, /g
              s/"//g
          '
    done
  done | grep "\<$1\>" | {

    # Handle output formatting
    test -n "${u_s_env_fmt:-}" || {
      test ! -t 1 || u_s_env_fmt=pretty
    }
    case "${u_s_env_fmt:-}" in
        ( pretty ) grep -v '^#' | sort | column -s ':' -t ;;
        ( ""|plain ) cat ;;
    esac
  }
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

# TODO: commands differs from handlers in that it lists maincmds and aliases
user_script_commands () # ~
{
  # FIXME: maincmds list are not functions, use aliases to resolve handler names
  test $# -gt 0 || set -- $script_maincmds
  user_script_resolve_aliases &&
  user_script_handlers "$@"
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

      # XXX: ( a|all ) shift && set -- user_scripts_all ;;

      ( --list-script-bases )
            test $# -eq 0 || shift; set -- user_script_bases "$@" ;;

      # Every good citizen on the executable lookup PATH should have these
      ( "-?"|-h|help )
            test $# -eq 0 || shift; set -- user_script_help "$@" ;;
      ( --help|long-help )
            test $# -eq 0 || shift; set -- user_script_longhelp "$@" ;;
      ( -V|--version|version )
            test $# -eq 0 || shift; set -- script_version "$@" ;;

      ( --aliases|aliases )
            test $# -eq 0 || shift; set -- user_script_aliases "$@" ;;

      ( --handlers|handlers ) # Display all potential handlers
            test $# -eq 0 || shift; set -- user_script_handlers "$@" ;;

      ( --commands|commands ) # ....
            test $# -eq 0 || shift; set -- user_script_commands "$@" ;;

      ( --env|variables )
            test $# -eq 0 || shift; set -- user_script_envvars "$@" ;;

  esac

  # Hook-in more from user-script
  test -z "${script_fun_xtra_defarg:=${script_xtra_defarg-}}" || {
    eval "$(sh_type_fun_body $script_fun_xtra_defarg)" || return
  }

  # Print everything using appropiate quoting
  argv_dump "$@"

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
  printf '; script_defcmd=%s' "$script_defcmd"
  printf '; script_cmddef=%s' "$defcmd"
}

user_script_envvars () # ~ # Grep env vars from loadenv
{
  local bid h
  for bid in $(user_script_bases)
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

# Transform glob to regex and invoke script-listfun for libs and other source
# files. This turns on script-listfun flag h by default.
user_script_handlers () # ~ [<Name-globs...>] # Grep function defs from main script
{
  test $# -eq 0 && {
    set -- "[A-Za-z_$US_EXTRA_CHAR][A-Za-z0-9_$US_EXTRA_CHAR]*"
  } || {
    set -- "$(grep_or "$@")"
  }

  # NOTE: some shell allow all kinds of characters in functions.
  # sometimes I define scripts as /bin/bash and use '-', maybe ':'.

  local name slf_h=${slf_h:-1}

  for name in $script_lib
  do
    script_listfun "$name" "$1" || true
  done

  for name in $script_src
  do
    script_listfun "$(command -v "$name")" "$1"
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

  for _baseid in $(${user_script_bases:-user_script_bases})
  do
    ! sh_fun "${_baseid}"_usage || break
  done

  "${_baseid}"_usage "$@"

  test $# -gt 0 -o ${longhelp:-0} -eq 0 || {

    # Add env-vars block, if there is one
    test ${longhelp:-0} -eq 0 || {
      envvars=$( user_script_envvars | grep -v '^#' | sed 's/^/\t/' )
      test -z "$envvars" ||
          printf '\nEnv vars:\n%s\n\n' "$envvars"
    }
  }
}

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

# Default loadenv for user-script, run at the end of doenv just before
# deferring to handler.
user_script_loadenv ()
{
  true "${US_BIN:="$HOME/bin"}" &&
    test -d "$US_BIN" &&

  user_script_loaded=1
}

user_script_longhelp () # ~ [<Name>]
{
  longhelp=1 user_script_help "$@"
}

# This should be run before calling any function
# TODO: rename user-script-helper-env

user_script_shell_env ()
{
  ! test "${user_script_shell_env:-}" = "1" || return 0

  user_script_shell_env=0

  set -e

  user_script_loadenv || { ERR=$?
    printf "ERR%03i: Cannot load user-script env" "$ERR" >&2
    return $ERR
  }

  . "$US_BIN"/os-htd.lib.sh || return
  user_script_libload \
      "${U_S:?}"/tools/sh/parts/fnmatch.sh \
      "${U_S:?}"/tools/sh/parts/sh-mode.sh &&
  test "${DEBUG:-0}" = "0" && {
      sh_mode strict || return
    } || {
      sh_mode strict dev || return
    }

  {
    . "$US_BIN"/str-htd.lib.sh &&
    . "$US_BIN"/argv.lib.sh &&
    . "$US_BIN"/user-script.lib.sh && user_script_lib_load &&

    . "${U_S:-/src/local/user-scripts}"/src/sh/lib/std.lib.sh &&

    #. ~/project/user-script/src/sh/lib/shell.lib.sh
    . "${U_C:-/src/local/user-conf-dev}"/script/shell-uc.lib.sh

  } || eval `sh_gen_abort '' "Loading libs status '$?'"`

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

  # Set everything about the shell we are working in
  shell_uc_lib_init || { ERR=$?
    printf "ERR%03i: Cannot initialze Shell lib" "$ERR" >&2
    return $ERR
  }

  test -z "${BASH_VERSION:-}" || {
  # XXX: test "$IS_BASH" = 1 -a "$IS_BASH_SH" != 1 && {

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

  test -z "${DEBUG:-}" ||
    : "${BASH_VERSION:?"Not sure how to do debug"}"

  test -z "${ALIASES:-}" || {
    : "${BASH_VERSION:?"Not sure how to do aliases"}"

    # Use shell aliases and templates to cut down on boilerplate for some
    # user-scripts.
    # This gives a sort-of macro-like functionality for shell scripts that is
    # useful in some contexts.
    shopt -s expand_aliases &&

    us_shell_alsdefs
  }

  user_script_shell_env=1
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

  # Resolve handler (if alias) and output formatted spec
  local us_aliases alias_sed handlers
  test $slf_l -eq 0 && {
      user_script_usage_handlers "$@" || {
        $LOG error "" "in" "$@"
        return 1
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
    $LOG error "" "No handler found"
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
    printf '\t%s (%s) %s\n' "$base" "$script_defcmd" ""
    printf '\n%s\n' "$script_shortdescr"
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
  alias_sed=$( echo "$us_aliases" | while read -r handler aliases
          do
              printf 's/^\<%s\>/( %s | & )/\n' "$handler" "${aliases// / | }"
          done
      )
  handlers=$(user_script_resolve_handlers "$@" | remove_dupes | lines_to_words)
}

# Output formatted help specs for one or more handlers.
user_script_usage_handlers ()
{
  user_script_fetch_handlers "$@"

  # Do any loading required for handler, so script-src/script-lib is set
  # XXX: not loading might speed up a bit, but only as long as AST is not
  # required later. See user-script-usage.
  ! sh_fun "${baseid}"_loadenv || {
    "${baseid}"_loadenv $handlers || return
  }

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
  us_shell_alias_defs \
  \
    sa_a1_act_lk   l-argv1-lk   act :-\$actdef ""         \${lkn:-\$act} -- \
    sa_a1_act_lk_2 l-argv1-lk   act :-\$actdef :-\$base:\$act  "" -- \
  \
    sa_a1_d_lk     de-argv1-lk      \$_1def    :?         \${lkn:-\$1} -- \
    sa_a1_d_lk_b   de-argv1-lk      \$_1def    :-\$base   \${lkn:-\$1} -- \
  \
    sa_E_nschc err-u-nsk \$lk "No such choice" "" 67 -- \
    sa_E_nsact err-u-nsk \$lk "No such action" \$act 67 -- \
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

  # Generic error+return
  uc_shell_alsdefs[err-u-nsk]='
    \$LOG error \"${1:-\$lk}\" \"${2:-"No such key/alias"}\" \"${3:-\$1}\";
    return ${4:-1}
  '
}

# NOTE: to be able to use us_shell_alias_defs, make sure you always call with
# fixed argument lengths to your templates.
us_shell_alias_def ()
{
  local als_name=${1:?} als_tpl=${2:?}
  shift 2
  eval "alias $als_name=\"${uc_shell_alsdefs[$als_tpl]}\""
}

# Call us-shell-alias-def for each argv sequence (separated by '--')
# XXX: a better version would use arrays I guess
us_shell_alias_defs ()
{
  while test $# -gt 0
  do
    us_shell_alias_def "$@" || return
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
  test "$script_cmddef" = "0"
}


# Main boilerplate (mostly useless except for testing this script)
# To list all user-script instances, see user-script.sh all.

! script_isrunning "user-script" .sh || {

  #. "${US_BIN:="$HOME/bin"}"/user-script.sh
  user_script_shell_env

  # Strip extension from SCRIPTNAME (and baseid)
  SCRIPT_BASEEXT=.sh
  # Default value used when argv is empty
  #script_defcmd=usage
  # Extra handlers for user-script-aliases to extract from
  #script_xtra_defarg={(user_script_bases)}_defarg
  # Extra defarg handlers to copy, used by default user-script-defarg impl.
  #script_fun_xtra_defarg=

  # Pre-parse arguments and reset argv: resolve aliased commands or sets default
  eval "set -- $(user_script_defarg "$@")"

  true "${US_EXTRA_CHAR:=:-}"

  # Execute argv and end shell
  script_entry "user-script" "$@" || exit
}

user_script_loaded=0
#
