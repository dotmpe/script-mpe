
### Comparing regex tools

# Looking if GNU grep can be replaced. Only for one generic test currently.

# Cannot get any benefit from ripgrep, sometimes for simple queries it
# underperforms even almost two magnitudes. Silversearch is much worse also.
#
# Cannot get ripgrep benchsuite to run without diving into source, but looking
# at a few of the provided benchmark summaries and by doing some local test
# runs I don't see much speed benefit.


source tools/benchmark/_lib.sh

runs=1

true "${testf:=htd.sh}"
bre='^ *\(#.*\)\?$'
re='^ *(#.*)?$'

test_1a_grep ()
{
  grep -v "$bre" "${testf:?}"
}

test_1b_egrep ()
{
  grep -Ev "$re" "${testf:?}"
}

test_2_ripgrep ()
{
  rg -v "$re" "${testf:?}"
}

test_2b_ripgrep ()
{
  rg -j1 -uuu -v "$re" "${testf:?}"
}

test_3_silversearcher ()
{
  ag -v "$re" "${testf:?}"
}


echo "Grep ($(test_1a_grep | wc -l) lines)"
time sh_null test_1a_grep
time sh_null run_test $runs 1a_grep
time sh_null run_test 10 1a_grep
echo

echo "Grep -E ($(test_1b_egrep | wc -l) lines)"
time sh_null test_1b_egrep
#time sh_null run_test $runs 1b_egrep
echo

echo "Rg ($(test_2_ripgrep | wc -l) lines)"
time sh_null test_2_ripgrep
#time sh_null run_test $runs 2_ripgrep
echo

echo "Rg -j1 -uuu ($(test_2b_ripgrep | wc -l) lines)"
time sh_null test_2b_ripgrep
#time sh_null run_test $runs 2b_ripgrep
echo

#echo "Ag ($(test_3_silversearcher | wc -l) lines)"
#time sh_null run_test $runs 3_silversearcher
#echo

re='\w+\s+Холмс\s+\w+'

echo "2. Grep -E ($(test_1b_egrep | wc -l) lines)"
time sh_null test_1b_egrep
#time sh_null run_test $runs 1b_egrep
echo

echo "2. Rg ($(test_2_ripgrep | wc -l) lines)"
time sh_null test_2_ripgrep
#time sh_null run_test $runs 2_ripgrep
echo

#
