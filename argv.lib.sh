#!/bin/sh

## argv:

# Functions to deal with script or function arguments.
# (for argv processing)
# nb. functions cannot access/change arguments of calling shell.


test_n ()
{
  test -n "${1-}"
}

# Verbose test + return status
# Also simple default helper for lookup-path
test_exists() # Local-Name [ Base-Dir ]
{
  test -z "$2" && {
    test -e "$1" || {
      error "No such file or path: $1"
      return 1
    }
  } || {
    test -e "$1/$2" && echo "$1/$2" || return 1
  }
}

test_equals()
{
  test "$1" = "$2"
}

test_dir() # path
{
  test -d "$1" || {
    error "no such dir: $1"
    return 1
  }
}

test_file() # Path
{
  test -f "$1" || {
    error "No such file: $1"
    return 1
  }
}

# test wether glob expands to itself
# XXX: which to use, what about symlinks.
test_glob() # Glob
{
  test "$(echo $1)" = "$1" && return 1 || return 0
#  for x in $1
#  do
#    test -e "$x" || return 1
#  done
}

# Simple helper to check for no or greater-/less-than argc
argv__argc () # ~ evttag argc test expectedc
{
  local tag="${1:-":(args)"}" test="${3:-"eq"}" expc="${4:-0}"
  test ${2:--1} -$test $expc || {
    $LOG error "$tag" "Expected argument count $test $expc, got ${2:--1}"
    return 64
  }
}

# Idem as argv__argc but also check every argument value is non-empty
argv__argc_n ()
{
  argv__argc "$@" || return
  local arg
  for arg in "$@"
  do
    test -n "$arg" && continue
    $LOG error "${1:-":(args-n)"}" "Got empty argument"
    return 63
  done
}

# Echo arguments as sh vars (use with local, export, etc)
arg_vars() # VARNAMES VALUES...
{
  local vars=$1
  shift
  for varname in $vars
  do
    test -z "$1" || {
      fnmatch "* *" "$1" && {
        printf " $varname=\"$1\""
      } || {
        printf " $varname=$1"
      }
    }
    shift
  done
  test -z "$1" || {
    error "surplus arguments: '$1'"
    return 1
  }
}

# Same as arg_vars but with usage, and debug verbosity
argv_vars()
{
  arg_vars "$@" || {
    echo "Usage: $0  $1" >&2
  }

  local vars=$1
  shift
  std_info "Parameters: $(
      for varname in $vars
      do
        printf " $varname=$1"
        shift
      done
    )"
}

# Abort on surplus arguments
check_argc()
{
  local argi=$(( $1 + 1 ))
  shift
  local value="$(eval echo \${$argi-})"
  test -z "$value" || error "surplus arguments (expected $1): '$value'" 1
}

# Find an executable script on path. Try with and without extension, in that
# order. Default extension: .phar
req_bin()
{
  test -n "$2" || set -- "$1" ".phar"
  test -x "$(which $1$2)" && {
    export $1_bin=$1$2
  } || {
    test -x "$(which $1)" && {
      export $1_bin=$1
    } || {
      error "Executable $1 required" 1
    }
  }
}


# Require at least one argument that is an existing path
req_path_arg()
{
  [ $# -gt 0 ] || error "Path or file name expected" 1
  [ -e "$1" ] || error "No such path or file '$1'" 1
}


# Require at least one argument that is a file
req_file_arg()
{
  [ $# -gt 0 ] || error "File name expected" 1
  [ -f "$1" ] || error "No file '$1'" 1
}


# Require at least one argument that is a non-empty file
req_fcontent_arg()
{
  [ $# -gt 0 ] || error "File name expected" 1
  [ -s "$1" ] || error "No such or empty file '$1'" 1
}


req_dir_arg()
{
  test -n "$1" -a -d "$1" || error "directory argument expected: '$1'" 1
}


# same as req-dir-arg but set argument to var 'path' also
req_cdir_arg()
{
  test -n "$1"  && path="$1"  || path=.
  req_dir_arg "$1"
}


req_file_env()
{
  while test $# -gt 0
  do
    value="$(eval echo "\$$1")"
    test -n "$value" || {
      error "file env '$1' expected but missing or empty ($?)" 1
    }
    test -f "$value" || {
      error "no such file for env '$1': $value" 1
    }
    shift
  done
}


req_dir_env()
{
  while test $# -gt 0
  do
    value="$(eval echo "\$$1")"
    test -n "$value" || {
      error "directory env '$1' expected but missing or empty ($?)" 1
    }
    test -d "$value" || {
      error "no such directory for env '$1': $value" 1
    }
    shift
  done
}


# opt-args: all argv are filtered into $options or else $arguments
opt_args()
{
  for arg in "$@"
  do { test "-" != "$arg" && fnmatch "-*" "$arg" ; } &&
      echo "$arg" >>$options || {
        test -n "$arg" &&
          echo "$arg" >>$arguments ||
          echo "''" >>$arguments
      }
  done
}


# Parse arguments as options
# -o123 --opt=123 --any-opt --no-opt
# o=123 op=123 any_opt=1 opt=0
define_var_from_opt () # Option [Var-Name-Pref]
{
  case "$1" in
    --*=* )
        key="$(str_strip_rx '=.*$' "$(echo "$1" | cut -c3-)")"
        value="$(str_strip_rx '^[^=]*=' "$1")"
        eval ${2-}$(echo "$key" | tr '-' '_')="$value"
      ;;
    --no-* )
        eval ${2-}$(echo "$1" | cut -c6- | tr '-' '_')=0
      ;;
    --* )
        eval ${2-}$(echo "$1" | cut -c3- | tr '-' '_')=1
      ;;

    - ) ;;

    # FIXME: short opt and opts with arg?
    -* )
        key="$(echo "$1" | cut -c2)"
        value="$(echo "$1" | cut -c3- )"
        eval ${2-}$(echo "$key" | tr '-' '_')="$value"
      ;;
    -* )
        eval ${2-}$(echo "$1" | cut -c2- | tr '-' '_')=1
      ;;

    * ) error "Not an option '$1'" 1 ;;
  esac
}

argv_arr_seq () # (argc:) ~ <Arr> <Argv...> [ -- <...> ]
{
  declare arg _argc=$# arr=${1:?}
  #sh_arr ${arr:?} || declare -ag "${arr:?}" || return
  shift
  while test 0 -lt $#
  do
    test "${1:?}" != "--" || {
      shift
      break
    }
    eval "$arr+=( \"\$1\" )"
    shift
  done
  argc=$(( _argc - $# - 1 ))
}

argv_has_next () # ~ <Argv...> # True if more for current sequence is available.
{
  test $# -gt 0 -a "${1-}" != "--"
}

argv_has_none () # ~ <Argv...> # True if argv is empty or before start of next sequence.
{
  test $# -eq 0 -o "${1-}" = "--"
}

argv_has_seq () # ~ <Argv...> # True if argv has sequence, except if the first is empty
{
  ! argv_has_none "$@" && fnmatch "* -- *" " $* "
}

argv_is_seq () # ~ <Argv...> # True if immediate item is '--' continuation.
{
  test "${1-}" = "--"
}

# Read arguments until --, accumulate more_argv and track more_argc.
# For convenience, this processes a leading '--' arg as well. So in that case
# instead of reading an empty or end-of sequence it reads the next.
# Returns false if no argv where handled.
#
# Typical usage is 'argv_more "$@" && shift $more_argc' and then handle
# $more_argv contents.
#
# NOTE: use argv_q to set quoting
argv_more () # ~ <Argv...> # Read until '--', and set $more_arg{c,v}
{
  test $# -gt 0 || return
  more_argc=$#
  # Don't require this but read leading '--' anyway
  argv_is_seq "$1" && shift

  test $# -eq 0 || {
    # Found empty sequence?
    argv_is_seq "$1" && { more_argv=; more_argc=1; return; }

    # Get all args
    test ${argv_q:-1} -eq 1 && more_argv="${1@Q}" || more_argv="$1"
    first=true
    while $first || argv_has_next "$@"
    do
      shift
      first=false
      test $# -gt 0 || break
      argv_is_seq "$1" || {
          test ${argv_q:-1} -eq 1 &&
              more_argv="$more_argv ${1@Q}" ||
              more_argv="$more_argv ${1}"
      }
    done
  }
  more_argc=$(( $more_argc - $# ))
}

argv_dump () # ~ <Argv...> # Print argv for re-eval
{
  while test $# -gt 0
  do
    # TODO: str_quote_shprop "$1"
    str_quote "$1"
    shift
    test $# -gt 0 || break
    printf ' '
  done
}

#
