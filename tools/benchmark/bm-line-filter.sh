#!/usr/bin/env bash

source tools/benchmark/_lib.sh

sh_mode strict

testfile=$HOME/.statusdir/index/context.list
runs=100


## Select part of matching lines

# I expected grep to be faster than sed, but this is often not the case but
# numbers are hard to reproduce and probably depend on other factors to a large
# degree.

# Sed is more flexible and `sed -n` does seem to run about just as fast
# as `grep -P`


echo -e "\nRunning grep -P regex..."
time < "$testfile" run_test $runs -- grep -Po '^#include \K.*'

echo -e "\nRunning sed -n s/.../gp"
time < "$testfile" run_test $runs -- sed -n 's/#include\ \(.*\)$/\1/gp'

#
