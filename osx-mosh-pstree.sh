#!/bin/sh

# Experimenting with mobile-shell
# A script to keep treeview ope nwith current docker processes


test -n "$1" || set -- launchd


#echo $PATH
#. ~/.bashrc || printf ""
PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export PATH

set -e

while true
do
  #echo $PATH

  #sleep 10
  #continue

  clear
  pstree-color.sh -s $1 \
    | tail -n +7 | more -SR

  sleep 60

done

