#!/bin/bash
if [ ! -d "$1" ];
then
    d=$(pwd);
else
    d=$1;
fi;

[ ! -d "$d" ] && exit 2

echo 'VC updates for' $d

DIRTY=
UPDATE=
CLEAN=

BZR=$(find "$d" -iname ".bzr")
HG=$(find "$d" -iname ".hg")

for f in $(find $d/ -iname '.git')
do
    cd $d;
    cd $(dirname $f);
    STATUS=$(git status -s)
    if [ -n "$STATUS" ];
    then 
        DIRTY="$DIRTY $f"
        continue
    fi;
    R=$(git pull origin master);
    if [ "$(echo $R|grep 'Already up-to-date')" ]
    then
        CLEAN="$CLEAN $f"
    else
        UPDATE="$UPDATE $f"
    fi
done;

echo "Clean"
for f in $CLEAN
do
    echo "	- $f"
done
echo "Dirty"
for f in $DIRTY
do
    echo "	- $f"
done
echo "Updates"
for f in $UPDATE
do
    echo "	- $f"
done

#for f in $HG;\
#do\
#    cd $(dirname $f);\
#    hg pull; hg update;\
#    cd $d;\
#done;\
#for f in $BZR;\
#do\
#    cd $(dirname $f);\
#    bzr pull;\
#    cd $d;\
#done

