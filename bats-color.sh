#!/bin/bash

# Powerline fonts
#  ✓  ok green/grey
#  ✗  error red white
#

while read line
do

  echo -e $( echo "$line" | sed -E '
    s/✓/\\033[0;32m&\\033[0m/g
    s/✗/\\033[0;31m&\\033[0m/g
    s/^ok/\\033[0;32m&\\033[0m/g
    s/^not ok/\\033[0;31m&\\033[0m/g
  ')

done
