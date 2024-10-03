#!/usr/bin/env bash

sh_debug_exit()
{
  local exit=$? ; test $exit -gt 0 || return 0
  test ${quiet:-0} -eq 0 && {
    sync
    {
      echo '------ sh-debug-exit: Exited: '$exit  >&2
      # NOTE: BASH_LINENO is no use at travis, 'secure'
      echo "At $BASH_COMMAND:$LINENO"
      echo "In 0:$0 base:${base-} scriptname:${scriptname-}"
    } >&2
    test "${SUITE-}" = "CI" || return $exit
    sleep 5
  }
  return $exit
}

#test ${COLORIZE:-0} -eq 0 || {
  . ${U_C:=/srv/project-local/user-conf-dev}/script/ansi-uc.lib.sh
  ansi_uc_lib__load
  ansi_uc_lib__init
#}

. ${U_C:=/srv/project-local/user-conf-dev}/script/bash-uc.lib.sh
trap bash_uc_errexit ERR

#test ${debug_exit_off:-${quiet-0}} -eq 1 || trap sh_debug_exit EXIT

# Sync: U-S:
