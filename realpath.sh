#!/bin/sh
# realpath - sh-implementation in 8 lines
path=`readlink -f $1` # Resolve links
if test ! -d $path
then
	name=`basename $path`
	path=`dirname $path`
fi	
path=`cd $path; pwd` # Normalize relative parts
echo $path/$name
