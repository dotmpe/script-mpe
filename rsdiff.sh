#!/bin/sh
#
# this acts as a remote diff program, accepting two files and displaying
# a diff for them.  Zero, one, or both files can be remote.  File paths
# must be in a format `scp` understands: [[user@]host:]file

if [ "$1" = "" -o "$2" = "" ]; then
    echo "Usage: `basename $0` file1 file2"
    exit 1
fi


f1=/tmp/rdiff.1
f2=/tmp/rdiff.2
scp $1 $f1
scp $2 $f2
if [ -f $f1 -a -f $f2 ]; then
	vimdiff -b $f1 $f2
fi
rm -f $f1 $f2

