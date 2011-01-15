#!/bin/sh

DIFF="/usr/bin/vimdiff"
# use the 6th and 7th parameter
#shift 5
#$DIFF "$@"
LEFT=${6}
RIGHT=${7}
$DIFF $LEFT $RIGHT


