#!/bin/bash
#
# dec-linedraw.sh
# Copyright (C) 2026 qwrt <qwrt@t460s>
#
# Distributed under terms of the MIT license.
#
PUT(){ echo -en "\033[${1};${2}H";}
DRAW(){ echo -en "\033%";echo -en "\033(0";}
# echo -en "\033(0"  # Enter line drawing
# echo -en "\033%"  # Select default/UTF-8 mode (compatibility, not required for
# line drawing)
WRITE(){ echo -en "\033(B";}
HIDECURSOR(){ echo -en "\033[?25l";}
NORM(){ echo -en "\033[?12l\033[?25h";}

function startBar() {
  local frame margin
  printf -v margin '%*s' ${_bar[margin]} ""
  frame[0]='lq'
  frame[1]='x '
  frame[2]='mq'
  for ((c=0; c<_bar[width]-4; c++)); do
    frame[0]+='q'
    frame[1]+='a'
    frame[2]+='q'
  done
  frame[0]+='qk'
  frame[1]+=' x'
  frame[2]+='qj'

  clear
  HIDECURSOR
  PUT 3 $(( _bar[center] - ( ${#1} / 2 ) + 1 ))
  echo "$1"
  DRAW
  printf "$margin"'%s\n' "${frame[@]}"
  WRITE
}

function renderBar() {
  pctDone=$(echo 'scale=2;'$1*100/${_bar[steps]} | bc)
  ((barPos=$1*(_bar[width]-4)/(_bar[steps]-1)))
  #barPos=$(echo "$1/${_bar[steps]}*(${_bar[width]}-4)" | bc)
  tput bold
  PUT 7 $(( _bar[center] - 2 )); printf "%4.4s%%" ${pctDone%.00}
  DRAW
  while (( _bar[pos] <= barPos )); do
    PUT 5 ${_bar[pos]}; printf 'E'
    ((_bar[pos]+=1))
  done
  WRITE
  echo
  PUT 9 0
  declare -p i pctDone barPos _bar
  tput sgr0
  echo
}

: "${0##*/}"
case "${_%.*sh}" in

( dec-linedraw )
    DRAW  # Enter line drawing mode
    for i in {a..z} {0..9} {A..Z} @; do
      echo -en "$i "
    done
    WRITE  # Back to normal
  ;;

( dec-progress-bar )
    #declare -gA _bar=( [margin]=5 [pos]=0 [width]=0 [steps]=10 )
    declare -gA _bar=( [margin]=8 [pos]=0 [width]=0 [steps]=60 )
    ((_bar[pos]+=_bar[margin]+3))
    : "${COLUMNS:=$(tput cols)}"
    ((_bar[width]=COLUMNS - (2 * _bar[margin])))
    ((_bar[center]=COLUMNS / 2))
    startBar "PLEASE WAIT WHILE SCRIPT IS IN PROGRESS"

    # ... Insert your script here
    for (( i=0; i<=_bar[steps]; i++ ))
    do
        renderBar $i
        sleep .02
    done
    # End of your script
    # Clean up at end of script
    PUT 10 12
    echo -e ""
    NORM
  ;;

( * )
    >&2 echo "${_}?"
    exit 2
esac
