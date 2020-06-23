#!/usr/bin/env bash

sh_debug_exit()
{
  local exit=$? ; test $exit -gt 0 || return 0 ; sync
  echo '------ sh-debug-exit: Exited: '$exit  >&2
  # NOTE: BASH_LINENO is no use at travis, 'secure'
  echo "At $BASH_COMMAND:$LINENO"
  echo "In 0:$0 scriptname:$scriptname"
  test "$USER" = "travis" || return $exit
  sleep 5 # Allow for buffers to clear?
  return $exit
}

trap sh_debug_exit EXIT

