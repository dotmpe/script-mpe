#!/bin/sh


# Functions to deal with script or function arguments.
# (for argv processing)
# nb. functions cannot access/change arguments of calling shell.


test_dir()
{
  test -d "$1" || {
    error "No such dir: $1"
    return 1
  }
}

test_file()
{
  test -f "$1" || {
    error "No such file: $1"
    return 1
  }
}

test_glob()
{
  for x in $1
  do
    test -e "$x" || return 1
  done
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

# Echo arguments as sh vars (use with local, export, etc)
arg_vars()
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
  info "Parameters: $(
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
  local value="$(eval echo \$$argi)"
  test -z "$value" || error "surplus arguments (expected $1): '$value'" 1
}

