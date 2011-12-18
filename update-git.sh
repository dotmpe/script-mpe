#!/bin/bash
d=.
[ -d "$1" ] && d=$1
[ -d "$d" ] || exit 1
[ "$origin" ] || ( echo Need to work from GIT checkout. && exit 2 )
[ "$EDITOR" ] || ( echo Editor environment not set. && exit 3 )
# Start
pwd=$(pwd -P)
cd $d
d=$(pwd -P)
echo "Echo now in $d"
origin=$(git remote -v|grep origin|grep fetch|sed -e 's/^origin.\(.*\)..fetch./\1/g')
echo 'Origin:' $origin

cd $pwd
echo "Back in $pwd"
