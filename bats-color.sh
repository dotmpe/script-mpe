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
    s/^(ok)(\ [0-9]*\ \#\ skip.*)/\\033[0;33m\1\\033[0m\2/g
    s/^ok/\\033[0;32m&\\033[0m/g
    s/^not ok/\\033[0;31m&\\033[0m/g
    s/^[0-9]*\.\.[0-9]*/\\033[1;37m&\\033[0m/g
    s/^[^(not\ ok\|ok*)].*/\\033[1;30m&\\033[0m/g
    s/\*/\\&/g
  ')

done
