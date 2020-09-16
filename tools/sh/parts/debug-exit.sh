#!/usr/bin/env bash

sh_debug_exit()
{
  local exit=$? ; test $exit -gt 0 || return 0 ; sync
  {
    echo '------ sh-debug-exit: Exited: '$exit  >&2
    echo "At $BASH_COMMAND:$LINENO"
    echo "In 0:$0 '$*' ($#) base:${base-} scriptname:${scriptname-}"
  } >&2
  test "${SUITE-}" = CI || return $exit
  test "$USER" = "travis" || return $exit
  sleep 5 # Allow a bit for log buffers to clear, on Travis before tearing tearing down
  return $exit
}

test ${debug_exit_off:-${quiet-0}} -eq 1 || trap sh_debug_exit EXIT

# Sync: U-S:
