#!/usr/bin/env bash

# Wait until ssh-add reports keys are available. Then start given program. A
# little experiment with support for interactive pseudo/virtual terminal.
#
# XXX: This seems rather tedious, bc sleep isnt responding normally to SIGINT.

# Only minimal env needed
set -euETo pipefail
trap - SIGINT
#us-env -R user-script -- "$@"

: "${_c3:=$(tput setaf 3)}"
: "${_c6:=$(tput setaf 6)}"
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
while true
do
  ! ((run)) || {
    ! 2>/dev/null >&2 ssh-add -L && {
      until 2>/dev/null >&2 ssh-add -L
      do
        echo "${_c6} ░  Waiting for SSH keys...${NORMAL}"
        sleep 5
      done
      clear
    }

    echo "${_c6}▒▒  SSH keys ready, starting '$*'${NORMAL}"
    "$@" && stat=$? || stat=$?
    ((stat)) &&
    echo "${_c3}    Command '$*' ended E$stat${NORMAL}" ||
    echo "${_c6}    Command '$*' ended OK${NORMAL}"
  }

  ! ((stat)) || {
    echo "${_c3} ▓  Command exited E$?, $0 will restart in $restart_delay seconds, press cancel to abort${NORMAL}"
    catch_sleep $restart_delay && continue || run=0 stat=0
  }

  echo "${_c6}██  Pending command: '$*', press 'r' to restart ${0##*/}, 'x' or cancel to exit${NORMAL}"
  read -r -s -N 1 prompt
  [[ $prompt == x ]] && exit ||
  [[ $prompt == r ]] && run=1 || run=0
done
