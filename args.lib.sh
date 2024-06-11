#!/bin/sh

## args:

# Functions to deal with script or function arguments.
# (for argv processing)
# nb. functions cannot access/change arguments of calling shell.


args_lib__load ()
{
  lib_require str
}


# Simple helper to check for no or greater-/less-than argc
args__argc () # ~ evttag argc test expectedc
{
  local tag="${1:-":(args)"}" test="${3:-"eq"}" expc="${4:-0}"
  test ${2:--1} -$test $expc || {
    $LOG error "$tag" "Expected argument count $test $expc, got ${2:--1}"
    return 64
  }
}

# Idem as args__argc but also check every argument value is non-empty
args__argc_n ()
{
  args__argc "$@" || return
  local arg
  for arg
  do
    test -n "$arg" && continue
    $LOG error "${1:-":(args-n)"}" "Got empty argument"
    return 63
  done
}

args_dump () # ~ <Argv...> # Print argv for re-eval
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

# True if no arguments are left or current sequence is empty
args_empty () # ~ <Argv...> # True if argv is empty or before start of next sequence.
{
  test $# -eq 0 -o "${1-}" = "${args_seq_end:---}"
}

args_has_next () # ~ <Argv...> # True if more for current sequence is available.
{
  test $# -gt 0 -a "${1-}" != "${args_seq_end:---}"
}

# Uses a simple globmatch to test if args-seq-end (--) is among argument words
args_has_seq () # ~ <Argv...> # True if argv contains some sequence, except if the first is empty
{
  ! args_empty "$@" && fnmatch "* ${args_seq_end:---} *" " $* "
}

# arguments-array-variable-hyphen-sequence
# Read sequence of arguments and flags until end '--' or long-option.
# Variant call on args-seq-arrv (arguments-sequence-array-variable:
args_hseq_arrv () # ~ <Arr> <Argv...> [--* ...]
{
  argv_more=args_opt_more args_seq_arrv "$@"
}
# alias: argv-hseq=args-hseq-arrv

# Reserve args.seq.end ('--') continuation marker for argument sequences
args_is_seq () # ~ <Argv...> # True if immediate item is seq. end '--'
{
  [[ "${1-}" = "${args_seq_end:---}" ]]
}

# Read arguments until --, accumulate more_args and track more_argc.
# For convenience, this processes a leading '--' arg as well. So in that case
# instead of reading an empty or end-of sequence it reads the next.
# Returns false if no argv where handled.
#
# Typical usage is 'args_more "$@" && shift $more_argc' and then handle
# $more_args contents.
#
# NOTE: use args_q to set quoting
# Comment:
#   The old args-more accumulates strings and does not use arrays.
#   args-seq-arrv is a newer variant using arrays.
args_more () # ~ <Argv...> # Read until '--', and set $more_arg{c,v}
{
  test $# -gt 0 || return
  more_argc=$#
  # Don't require this but read leading '--' anyway
  args_is_seq "$1" && shift

  test $# -eq 0 || {
    # Found empty sequence?
    args_is_seq "$1" && { more_args=; more_argc=1; return; }

    # Get all args
    test ${args_q:-1} -eq 1 && more_args="${1@Q}" || more_args="$1"
    first=true
    while $first || args_has_next "$@"
    do
      shift
      first=false
      test $# -gt 0 || break
      args_is_seq "$1" || {
          test ${args_q:-1} -eq 1 &&
              more_args="$more_args ${1@Q}" ||
              more_args="$more_args ${1}"
      }
    done
  }
  more_argc=$(( more_argc - $# ))
}

args_opt_more () # ~ <Argv...> # True if more arguments (non-long-option or seq end)
{
  [[ $# -gt 0 && "${1:0:2}" != "${args_seq_end:---}" ]]
}

# arguments-offset-sequence-array-variable
args_oseq_arrv () # ~ <offset> <arr> <args...> [--* ...]
{
  declare __offset=${1:?} &&
  declare -n __arr=${2:?} &&
  __arr+=( "${@:3:$__offset}" ) &&
  __offset=$(( 3 + __offset )) &&
  ${args_seq:-args_seq_arrv} "$2" "${@:$__offset}"
}
# alias: argv-oseq=args-seq-arrvo

# arguments-reverse: Reverse argument list
args_rev () # ~ <Items...>
{
  local c
  for (( c=$#; c>0; --c ))
  do
    echo "${!c}"
  done
}

args_rarr () # ~ <Array> <Args..>
{
  local c
  declare -n arr=${1:?}
  for (( c=$#; c>0; --c ))
  do
    arr+=( "${!c}" )
  done
}

# arguments-sequence-array-variable:
# Reads sequence of arguments (until '--', ie. args-seq-end marker) into array
args_seq_arrv () # ~ <Arr> <Argv... [-*]> <...>
{
  declare __si=2
  declare -n __arr=${1:?}
  while ${argv_more:-args_seq_more} "${@:$__si}"
  do
    __arr+=( "${!__si}" )
    __si=$(( __si + 1 ))
  done
}
# alias argv-seq=args-seq-arrv

args_seq_more () # ~ <Argv...> # True if more for current sequence is available.
{
  [[ $# -gt 0 && "${1-}" != "${args_seq_end:---}" ]]
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


# opt-args: all argv are filtered into $options or else $arguments
opt_args()
{
  for arg
  do { test "-" != "$arg" && fnmatch "-*" "$arg" ; } &&
      echo "$arg" >>$options || {
        test -n "$arg" &&
          echo "$arg" >>$arguments ||
          echo "''" >>$arguments
      }
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
      error "Executable $1 required" ${_E_user:?}
    }
  }
}

# same as req-dir-arg but set argument to var 'path' also
req_cdir_arg()
{
  test -n "$1"  && path="$1"  || path=.
  req_dir_arg "$1"
}


req_dir_arg()
{
  test -n "$1" -a -d "$1" || error "directory argument expected: '$1'" 1
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

# Require at least one argument that is a non-empty file
req_fcontent_arg()
{
  [ $# -gt 0 ] || error "File name expected" 1
  [ -s "$1" ] || error "No such or empty file '$1'" 1
}


# Require at least one argument that is a file
req_file_arg()
{
  [ $# -gt 0 ] || error "File name expected" 1
  [ -f "$1" ] || error "No file '$1'" 1
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

# Require at least one argument that is an existing path
req_path_arg()
{
  [ $# -gt 0 ] || error "Path or file name expected" 1
  [ -e "$1" ] || error "No such path or file '$1'" 1
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

#
