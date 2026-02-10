#!/usr/bin/env bash

set -euETo pipefail
trap - SIGINT


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
  sleep 10
  trap - SIGINT
  set -e
  ! ((stop))
}

: "${run:=1}"
stat=0
while true
do
  ! ((run)) || {
    read -r -p "Enter any key to activate terminal " -n 1
    "$@" && stat=$? || stat=$?
    echo "Command '$*' ended E$stat"
  }

  ! ((stat)) || {
    echo "Command exited E$?, $0 will restart in 10 seconds, press cancel to abort"
    catch_sleep 10 && continue || run=0 stat=0
  }

  echo "Command pending: '$*', press 'r' to restart, 'x' or cancel to exit"
  read -r -s -N 1 prompt
  [[ $prompt == x ]] && exit ||
  [[ $prompt == r ]] && run=1 || run=0
done

