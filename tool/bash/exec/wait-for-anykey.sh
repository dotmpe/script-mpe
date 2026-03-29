#!/usr/bin/env bash

set -euETo pipefail
trap - SIGINT
stty -echoctl

: "${_c2:=$(tput setaf 2)}"
: "${_c3:=$(tput setaf 3)}"
: "${_c4:=$(tput setaf 4)}"
: "${_c6:=$(tput setaf 6)}"
: "${_c15:=$(tput setaf 15)}"
: "${NORMAL:=$(tput sgr0)}"
: "${BOLD:=$(tput bold)}"

: "${restart_delay:=10}"

test-int ()
{
  stop=1
  return
}

# Tweak the behavior of GNU core sleep
catch_sleep ()
{
  local stop=0
  trap 'test-int' SIGINT
  set +e
  #stty -echoctl
  sleep ${1:-300}
  trap - SIGINT
  #stty echoctl
  set -e
  ! ((stop))
}

while [[ ${1:+set} && ${1} == *=* ]]
do
  declare "$1"
  shift
done

: "${run:=1}"
stat=0
wait=1
while true
do
  ! ((run)) || {
    ! ((wait)) || {
      clear
      read -r -p "${_c2} ░░░ Enter ${_c6} ${_c15}any key ${_c6} ${_c2}to activate terminal${NORMAL} " -n 1
    }
    "$@" && stat=$? || stat=$?
    ((stat)) &&
    echo "${_c2} 🮙🮙🮙 Command '$*' ended ${_c3}E$stat${NORMAL}" ||
    echo "${_c2} ▒▒▒ Command '$*' ended OK"
  }

  ! ((stat)) || {
    echo "${_c2} ▓▓▓ Command exited ${_c3}E$?${_c2}, ${0##*/} will restart in $restart_delay seconds, interrupt to abort${NORMAL}"
    catch_sleep $restart_delay && continue || run=0 stat=0
  }

  echo "${_c2} ███ Command completed: '$*'. Press 'R' to reset, 'r' to restart ${0##*/} COMMAND now, and 'x' or interrupt to exit${NORMAL}"
  read -r -s -N 1 prompt &&
  [[ ${prompt-} != x ]] || exit 0

  [[ ${prompt-} == R ]] && run=1 wait=1 || {
    [[ ${prompt-} == r ]] && run=1 wait=0 || run=0
  }
  ((run)) &&
  echo "${_c2} 🮙🮙🮙 Resetting for command '$*'" ||
  echo "${_c2} 🮙🮙🮙 Restarting command '$*'"
done

