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

# Tweak the behavior of Bash builtin+traps by wrapping in function
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

redraw ()
{
  tput rc 2>/dev/null || :  # restore cursor
  tput ed 2>/dev/null || :  # clear to end of display
  printf '%s\n' "${prompt}"
}


while [[ ${1:+set} && ${1} == *=* ]]
do
  declare -x "$1"
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
      trap 'redraw' WINCH
      prompt="${_c2} ░░░ Enter ${_c6} ${_c15}any key ${_c6} ${_c2}to activate terminal${NORMAL} "
      # FIXME: catch interrupt to prevent closing of window
      read -r -p "$prompt" -n 1
      trap - WINCH
      prompt=
    }
    command "$@" && stat=$? || stat=$?
    ((stat)) &&
    echo "${_c2} 🮙🮙🮙 Command '$*' ended ${_c3}E$stat${NORMAL}" ||
    echo "${_c2} ▒▒▒ Command '$*' ended OK"
  }

  ! ((stat)) || {
    prompt="${_c2} ▓▓▓ Command exited ${_c3}E$?${_c2}, ${0##*/} will restart in $restart_delay seconds, interrupt to abort${NORMAL}"
    trap 'redraw' WINCH
    printf '%s\n' "$prompt"
    catch_sleep $restart_delay && {
      trap - WINCH
      prompt=
      continue
    } || run=0 stat=0
    trap - WINCH
    prompt=
  }

  prompt="${_c2} ███ Command completed: '$*'. Press 'R' to reset, 'r' to restart ${0##*/} COMMAND now, and 'x' or interrupt to exit${NORMAL}"
  trap 'redraw' WINCH
  printf '%s\n' "$prompt"

  read -r -s -N 1 reply &&
  [[ ${reply-} != x ]] || exit 0
  trap - WINCH
  prompt=

  [[ ${reply-} == R ]] && run=1 wait=1 || {
    [[ ${reply-} == r ]] && run=1 wait=0 || run=0
  }
  ((run)) &&
  echo "${_c2} 🮙🮙🮙 Resetting for command '$*'" ||
  echo "${_c2} 🮙🮙🮙 Restarting command '$*'"
done

