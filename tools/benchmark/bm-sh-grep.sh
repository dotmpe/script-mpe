
### Comparing regex tools

# Looking if GNU grep can be replaced.

# Ripgrep can perform better on large files. Not sure, it may be interesting
# to compare the Linux src test with personal use cases. As for grepping ASCII
# source scripts it looks like grep can easily out-do it, XXX: so need to try
# and turn utf-8 off.

source tools/benchmark/_lib.sh

runs=10

# Tried to get some results but there is too much noise currently on my dev.

true "${testf:=htd.sh}"
bre='^ *\(#.*\)\?$'
re='^ *(#.*)?$'

test_1a_grep ()
{
  LC_ALL="en_US.utf-8" grep -v "$bre" "${testf:?}"
}

test_1a2_grep_C ()
{
  LC_ALL=C grep -v "$bre" "${testf:?}"
}

test_1b_egrep ()
{
  grep -Ev "$re" "${testf:?}"
}

test_1b2_egrep_C ()
{
  LC_ALL=C grep -Ev "$re" "${testf:?}"
}

test_2a_ripgrep ()
{
  rg -v "$re" "${testf:?}"
}

test_2b1_ripgrep_C ()
{
  LC_ALL=C rg -v "$re" "${testf:?}"
}

test_2b2_ripgrep ()
{
  rg -j1 -uuu -v "$re" "${testf:?}"
}

test_2b3_ripgrep ()
{
  rg -v "$re" "${testf:?}"
}

# XXX: tweak options/env?
test_3_silversearcher ()
{
  ag -v "$re" "${testf:?}"
}


## 1. grep

echo "Grep ($(test_1a_grep | wc -l) lines)"
#time sh_null test_1a_grep
time sh_null run_test $runs 1a_grep
#time sh_null run_test 10 1a_grep
echo

echo "Grep ($(test_1a2_grep_C | wc -l) lines)"
#time sh_null test_1a2_grep_C
time sh_null run_test $runs 1a2_grep_C
echo

echo "Grep -E ($(test_1b_egrep | wc -l) lines)"
#time sh_null test_1b_egrep
time sh_null run_test $runs 1b_egrep
echo

echo "Grep -E ($(test_1b2_egrep_C | wc -l) lines)"
#time sh_null test_1b2_egrep_C
time sh_null run_test $runs 1b2_egrep_C
echo


## 2. ripgrep

echo "Rg (C)($(test_2b1_ripgrep_C | wc -l) lines)"
#time sh_null test_2b1_ripgrep_C
time sh_null run_test $runs 2b1_ripgrep_C
echo

echo "Rg -j1 -uuu ($(test_2b2_ripgrep | wc -l) lines)"
#time sh_null test_2b2_ripgrep
time sh_null run_test $runs 2b2_ripgrep
echo

echo "Rg ($(test_2b3_ripgrep | wc -l) lines)"
#time sh_null test_2b3_ripgrep
time sh_null run_test $runs 2b3_ripgrep
echo


#echo "Ag ($(test_3_silversearcher | wc -l) lines)"
#time sh_null run_test $runs 3_silversearcher
#echo

#re='\w+\s+Холмс\s+\w+'
#
#echo "2. Grep -E ($(test_1b_egrep | wc -l) lines)"
#time sh_null test_1b_egrep
##time sh_null run_test $runs 1b_egrep
#echo
#
#echo "2. Rg ($(test_2_ripgrep | wc -l) lines)"
#time sh_null test_2_ripgrep
##time sh_null run_test $runs 2_ripgrep
#echo

#
