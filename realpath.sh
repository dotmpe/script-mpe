#!/bin/sh
# realpath - sh-implementation in a few lines
path=`readlink -f $1` # Resolve links
if test ! -d $path
then
	name=`basename $path`
	path=`dirname $path`
fi	
path=`cd $path; pwd` # Normalize relative parts
if test ! -z "$name"
then	
	echo $path/$name
else
	echo $path
fi	
