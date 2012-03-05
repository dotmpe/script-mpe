#!/bin/bash 

# Usage: movelink file target(dir)

[ ${#} -ne 2 ] && echo "Two arguments: source destination. " >&2 && exit 1;

f=$1
[ ! -e "$f" ] && echo "Source must exist: $f" >&2 && exit 2
( [ ! -f "$f" ] && [ ! -L "$f" ] )  && echo "Source must be file or symlink: $f" >&2 && exit 2

d=$2
( [ ! -d "$d" ] && [ -e "$d" ] ) && echo "Destination must not exist or be a folder: $d" >&2 && exit 2


if [ ! -d "$d" ]
then
    D=$(dirname $d)
    F=$(basename $d)
else
    D=$d
    F=$(basename $f)
fi

S=$(dirname $f | sed 's/[^((\.\.)|(\.))\/]\+\/\?/..\//g')

#mv $f $D/$F
echo ln -s $S/$D/$F $f

[ -e "$f" ] || exit 31

exit 0
