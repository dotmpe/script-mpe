#!/usr/bin/env bash

set -euETo pipefail
trap - SIGINT

: "${_c2:=$(tput setaf 2)}"
: "${_c3:=$(tput setaf 3)}"
: "${_c6:=$(tput setaf 6)}"
: "${_c15:=$(tput setaf 15)}"
: "${NORMAL:=$(tput sgr0)}"

: "${restart_delay:=10}"

test-int ()
{
  stop=1
  return
}

catch_sleep ()
{
  local stop=0
  trap 'test-int' SIGINT
  set +e
  sleep ${1:-300}
  trap - SIGINT
  set -e
  ! ((stop))
}

: "${run:=1}"
stat=0
wait=1
while true
do
  ! ((run)) || {
    ! ((wait)) || {
      clear
      read -r -p "${_c2}░░░ Enter ${_c6} ${_c15}any key ${_c6} ${_c2}to activate terminal${NORMAL} " -n 1
    }
    "$@" && stat=$? || stat=$?
    echo "${_c2}▒   Command '$*' ended E$stat${NORMAL}"
  }

  ! ((stat)) || {
    echo "${_c2}▓   Command exited ${_c3}E$?${_c2}, $0 will restart in $restart_delay seconds, interrupt to abort${NORMAL}"
    catch_sleep $restart_delay && continue || run=0 stat=0
  }

  echo "${_c2}█   Command completed: '$*'. Press 'R' to reset, 'r' to restart ${0##*/} COMMAND now, and 'x' or interrupt to exit${NORMAL}"
  read -r -s -N 1 prompt &&
  [[ ${prompt-} != x ]] || exit 0

  [[ ${prompt-} == R ]] && run=1 wait=1 || {
    [[ ${prompt-} == r ]] && run=1 wait=0 || run=0
  }
done

