#!/usr/bin/env bash

# Wait until ssh-add reports keys are available. Then start given program. A
# little experiment with support for interactive pseudo/virtual terminal.
#
# XXX: This seems rather tedious, bc sleep isnt responding normally to SIGINT.

# Only minimal env needed
set -euETo pipefail
trap - SIGINT
#us-env -R user-script -- "$@"

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
    while ! 2>/dev/null >&2 ssh-add -L
    do
      echo "Waiting for SSH keys..."
      sleep 5
    done

    echo "SSH keys ready, starting '$*'"
    "$@" && stat=$? || stat=$?
    echo "Command '$*' ended E$stat"
  }

  ! ((stat)) || {
    echo "Command exited E$?, wait-for-ssh-keys will restart in 10 seconds, press cancel to abort"
    catch_sleep 10 && continue || run=0 stat=0
  }

  echo "Command pending: '$*', press 'r' to restart, 'x' or cancel to exit"
  read -r -s -N 1 prompt
  [[ $prompt == x ]] && exit ||
  [[ $prompt == r ]] && run=1 || run=0
done
