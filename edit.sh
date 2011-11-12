#!/bin/bash
origin=$(git remote -v|grep origin|grep fetch|sed -e 's/^origin.\(.*\)..fetch./\1/g')
echo 'Origin:' $origin
git fetch origin master
git diff HEAD -- $1
( 
    [ "$(git status $1 | grep Untracked)" ] \
    && echo New file: $1
) || (
    [ "$(git status $1 | grep Modified)" ] \
    && echo Modified file: $1
)

