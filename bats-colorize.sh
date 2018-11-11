#!/bin/bash

# Powerline fonts codepoints for test OK check and NOT-OK cross mark
#  ✓  ok green/grey
#  ✗  error red white
#

while read line
do

  echo -e $( echo "$line" | sed -E '

    s/✓/\\033[0;32m&\\033[0m/g
    s/✗/\\033[0;31m&\\033[0m/g

    s/^[0-9]*\.\.[0-9]*/\\033[1;37m&\\033[0m/g
    s/^[^(not\ ok\|ok*)].*/\\033[1;30m&\\033[0m/g

    s/^([notk]*\ [0-9]*\ \#\ )(TODO)(\ \(.*\))(.*)/\\033[1;30m\1\\033[0;36m\2\\033[1;37m\3\\033[0;37m\4/g
    s/^([notk]*\ [0-9]*\ \#\ )(skip)(\ \(.*\))(.*)/\\033[1;30m\1\\033[0;33m\2\\033[1;37m\3\\033[0;37m\4/g

    s/^ok/\\033[0;32m&\\033[0m/g
    s/^not ok/\\033[0;31m&\\033[0m/g

    s/\*/\\&/g

  ')


done

# tasks-ignore-file
