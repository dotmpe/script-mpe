
### Comparing regex tools


# Cannot get any benefit from ripgrep, for simple queries it underperforms by
# one, almost two magnitudes. Silversearch is even much worse.
#
# Cannot get ripgrep benchsuite to run without diving into source, but looking
# at the provided benchmark summaries and by doing some local test runs I don't
# see any speed benefit to ripgrep, in fact the opposite. It does not even run
# at similar speeds to grep but takes about 500 times longer!


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

test_3_silversearcher ()
{
  ag -v "$re" "${testf:?}"
}


echo "Grep ($(test_1a_grep | wc -l) lines)"
time run_test_q $runs 1a_grep
echo
echo "Grep -E ($(test_1b_egrep | wc -l) lines)"
time run_test_q $runs 1b_egrep
echo

echo "Rg ($(test_2_ripgrep | wc -l) lines)"
time run_test_q $runs 2_ripgrep
echo

#echo "Ag ($(test_3_silversearcher | wc -l) lines)"
#time run_test_q $runs 3_silversearcher
#echo

re='\w+\s+Холмс\s+\w+'

echo "2. Grep -E ($(test_1b_egrep | wc -l) lines)"
time run_test_q $runs 1b_egrep
echo

echo "2. Rg ($(test_2_ripgrep | wc -l) lines)"
time run_test_q $runs 2_ripgrep
echo

#
