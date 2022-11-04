
## Benchmark methods to remove last character from line

# A common problem that 'cut' by itself cannot tackle, but for which 'sed'
# seems overkill.

# read+strl  0.8s / 1000
# sed        1.8s / "
# rev+cut    2.0s / "
# awk-sub    2.4s / "
# awk-strl   2.5s / "

# Intent was to look at relative cost/speed per method, ofcourse without
# re-invocations doing stream processing throughput for all external tools
# improved dramatically. See next results.
# But (somewhat counterintuitively to me) plain old Bash still wins for such a
# simple operation. Note that the easy and often used 'sed' method which is the
# shortest of the commands does the worst.

# read+strl  1.6s / 100000
# rev+cut    1.7s / "
# awk-sub    1.8s / "
# awk-strl   1.8s / "
# sed        1.8s / "

# awk-sub is only slightly ahead awk-strl, sed is almost 0.1s slower.
# Readline with Bash string slicing is still the winner.


test_awk_sub ()
{
  awk '{sub(/.$/,"",$1); print $1}'
}

test_awk_strl ()
{
  awk '{sub(/.$/,"",$1); print $1}'
}

test_sed ()
{
  sed 's/.$//'
}

test_read_strl ()
{
  local str len
  while read -r str
  do
    len=$(( ${#str} - 1 ))
    echo "${str:0:$len}"
  done
}

test_rev_cut ()
{
  rev | cut -c 2- | rev
}


# Util

test_data ()
{
  echo "foo/"
}

test_io ()
{
  test_data | "$@" >/dev/null
}

source tools/benchmark/_lib.sh

runs=1000
for tc in awk_sub awk_strl sed rev_cut read_strl
do
  echo -e "\nTesting $tc..."
  time run_test $runs io test_$tc
done
exit

runs=100000
for tc in awk_sub awk_strl sed rev_cut read_strl
do
  echo -e "\nTesting $tc..."
  time run_test_io test_ $runs test_data $tc
done
