#!/bin/sh

# Sys: lower level Sh helpers; dealing with vars, functions, and other shell
# ideosyncracities

set -e



incr()
{
  local incr_amount
  test -n "$2" && incr_amount=$2 || incr_amount=1
  v=$(eval echo \$$1)
  export $1=$(( $v + $incr_amount ))
}

# test for var decl, io. to no override empty
var_isset()
{
  # Aside from declare or typeset in newer reincarnations,
  # in posix or modern Bourne mode this seems to work best:
  set | grep '\<'$1'=' >/dev/null 2>/dev/null && return
  return 1
}

# require vars to be initialized, regardless of value
req_vars()
{
  while test $# -gt 0
  do
    var_isset "$1" || return 1
    shift
  done
}

# No-Op(eration)
noop()
{
  . /dev/null # source empty file
  #echo -n # echo nothing
  #printf "" # id. if echo -n incompatible (Darwin)
  #set -- # clear arguments (XXX set nothing?)
}

trueish()
{
  test -n "$1" || return 1
  case "$1" in
		[Oo]n|[Tt]rue|[Yy]|[Yy]es|1)
      return 0;;
    * )
      return 1;;
  esac
}

cmd_exists()
{
  test -x $(which $1) || return $?
}

func_exists()
{
  type $1 2> /dev/null 1> /dev/null || return $?
  # XXX bash/bsd-darwin: test "$(type -t $1)" = "function" && return
  return 0
}

try_exec_func()
{
  test -n "$1" || return 97
  func_exists $1 || return $?
  local func=$1
  shift 1
  $func "$@" || return $?
}

try_var()
{
  local value="$(eval echo "\$$1")"
  test -n "$value" || return 1
  echo $value
}

