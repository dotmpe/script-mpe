#!/usr/bin/env bash

set -euETo pipefail
trap - SIGINT

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
    clear
    read -r -p "░░░ Enter  any key  to activate terminal " -n 1
    "$@" && stat=$? || stat=$?
    echo "░  Command '$*' ended E$stat"
  }

  ! ((stat)) || {
    echo "▓  Command exited E$?, $0 will restart in $restart_delay seconds, interrupt to abort"
    catch_sleep $restart_delay && continue || run=0 stat=0
  }

  echo "▒  Command completed: '$*'. Press 'r' to restart, and 'x' or interrupt to exit"
  read -r -s -N 1 prompt
  [[ $prompt == x ]] && exit ||
  [[ $prompt == r ]] && run=1 || run=0
done

