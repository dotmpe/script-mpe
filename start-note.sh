#!/bin/sh

file=$HOME/htdocs/current.list
test -f $file || {
    echo "# Current list on $(date --iso=min)" >$file
}

vim \
    -c "norm Go" \
    -c "startinsert" $file
