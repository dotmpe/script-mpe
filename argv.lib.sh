#!/bin/sh


# Functions to deal with script or function arguments.
# (for argv processing)
# nb. functions cannot access/change arguments of calling shell.


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

test_dir() # Path
{
  test -d "$1" || {
    error "No such dir: $1"
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

# XXX: test wether glob expands to itself
test_glob() # Glob
{
  test "$(echo $1)" = "$1" && return 1 || return 0
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


# Exit on error


# Abort on surplus arguments
check_argc()
{
  local argi=$(( $1 + 1 ))
  shift
  local value="$(eval echo \$$argi)"
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
define_var_from_opt()
{
  case "$1" in
    --*=* )
        key="$(str_strip_rx '=.*$' "$(echo "$1" | cut -c3-)")"
        value="$(str_strip_rx '^[^=]*=' "$1")"
        eval $(echo "$key" | tr '-' '_')="$value"
      ;;
    --no-* )
        eval $(echo "$1" | cut -c6- | tr '-' '_')=0
      ;;
    --* )
        eval $(echo "$1" | cut -c3- | tr '-' '_')=1
      ;;

    - ) ;;

    # FIXME: short opt and opts with arg?
    -* )
        key="$(echo "$1" | cut -c2)"
        value="$(echo "$1" | cut -c3- )"
        eval $(echo "$key" | tr '-' '_')="$value"
      ;;
    -* )
        eval $(echo "$1" | cut -c2- | tr '-' '_')=1
      ;;

    * ) error "Not an option '$1'" 1 ;;
  esac
}

