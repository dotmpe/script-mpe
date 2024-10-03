#!/usr/bin/env bash

source tools/benchmark/_lib.sh

sh_mode strict

testfile=$0
testfile=test/var/txs_help.txt
runs=100
suffix=\ concat\ string

## Append $suffix to each line.

# These numbers are no surpise for anyone who has done profiling on simple
# string operations in shell vs. sed/awk scripts: a shell read/echo loop beats
# running any other program by a large margin, let alone running a complete
# pipeline if a single string concat is the only op. Measured a baseline here
# of about 0.07 sec / 100.
# sed, join and awk all take almost or more than 4 times longer.
# join does a bit better than those, it only takes 3 times more.
# The paste/head/yes/wc pipeline script is 0.5s/100: more than 7 times.

# See also
# <https://stackoverflow.com/questions/2869669/in-bash-how-do-i-add-a-string-after-each-line-in-a-file>

test_shell ()
{
  while read -r line; do echo ${line}${suffix}; done
}

test_shell2 ()
{
  while read l ; do printf '%s\n' "$l" "${suffix}" ; done
}

test_xargs ()
{
  xargs -0 -L 1 printf "%s${suffix}\n"
}

test_join ()
{
  join "${1:?}" "${1:?}" -e "${suffix}" -o 1.1,2.99999
}

test_pastepl ()
{
  paste "${1:?}" <(yes "${suffix}" | head -$(wc -l < "${1:?}") )
}


base=$(basename -- "$0" .sh)

echo -e "\n$base: Running awk...";
time run_test_q $runs -- awk -v "suffix=$suffix" '{print $0, suffix}' < $testfile

echo -e "\n$base: Running sed...";
time run_test_q $runs -- sed 's/$/'"$suffix"'/g' < $testfile

echo -e "\n$base: Running bash read/echo...";
time run_test_q $runs shell < $testfile

echo -e "\n$base: Running bash read/printf...";
time run_test_q $runs shell2 < $testfile

echo -e "\n$base: Running xargs/printf...";
time run_test_q $runs xargs < $testfile

echo -e "\n$base: Running join...";
time run_test_q $runs join $testfile

echo -e "\n$base: Running paste pipeline...";
time run_test_q $runs pastepl $testfile


#
