#!/bin/bash
#
# dec-linedraw.sh
# Copyright (C) 2026 qwrt <qwrt@t460s>
#
# Distributed under terms of the MIT license.
#
PUT(){ echo -en "\033[${1};${2}H";} # tput cup
UP(){ echo -en "\033[${1}A";} # tput cuu
DOWN(){ echo -en "\033[${1}B";} # tput cud
# ESC % is ISO 2022 character switch, for default reset I presume.
# Acceptable also should be
# ESC % G for UTF-8
# ESC % @ for ISO 8859-1
DRAW(){ echo -en "\033%";echo -en "\033(0";} # tput smacs
# echo -en "\033(0"  # Enter line drawing
# echo -en "\033%"  # Select default/UTF-8 mode (compatibility, not required for
# line drawing)
WRITE(){ echo -en "\033(B";} # tput rmacs
HIDECURSOR(){ echo -en "\033[?25l";}
NORM(){ echo -en "\033[?12l\033[?25h";}
CLEAR(){ echo -en "\033[2J\033[H";}  # clear screen
BOTTOM(){ echo -en "\033[999;1H\033[K";}  # bottom line
CLEARLINE(){ echo -en "\r\033[K";}  # clear line

function startBarFrame() {
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

( dec-progress-bar-frame )
    #declare -gA _bar=( [margin]=5 [pos]=0 [width]=0 [steps]=10 )
    declare -gA _bar=( [margin]=8 [pos]=0 [width]=0 [steps]=60 )
    ((_bar[pos]+=_bar[margin]+3))
    : "${COLUMNS:=$(tput cols)}"
    ((_bar[width]=COLUMNS - (2 * _bar[margin])))
    ((_bar[center]=COLUMNS / 2))
    startBarFrame "PLEASE WAIT WHILE SCRIPT IS IN PROGRESS"

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

( dec-progress-bar )
    LINES=$(tput lines)
    CLEAR
    HIDECURSOR
    TOTAL=1000
    spin=0
    spinner=( '\' '|' '/' '-' )
    for i in $(seq 1 $TOTAL); do
        # normal output (above bar)
        CLEARLINE
        #BOTTOM
        #UP
        #CLEARLINE
        #PUT $(( LINES - 2 )) 0
        #CLEARLINE
        #PUT $(( LINES - 3 )) 0
        echo "Processing item $i..."

        # redraw bar at bottom
        PERC=$((i*100/TOTAL))
        BOTTOM
        ((spin+=1))
        ((spin<=3)) || ((spin-=4))
        echo -en "[${spinner[spin]}] Progress: ["
        DRAW
        printf "%${PERC}s" | tr ' ' 'E'
        printf "%$((100-PERC))s" | tr ' ' 'a'
        WRITE
        echo -en "] $PERC%"
        #UP
        #echo -e "\r1"
        #UP
        #echo -e "\r2"
        #UP

        sleep 0.05
    done

    NORM
    echo
  ;;

( * )
    >&2 echo "${_}?"
    exit 2
esac
