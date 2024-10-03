
# Looking at how fast a regex test does for a simple two-char check.

# regex 1.7s/100000 = 1.7 ms
# test  1.5s/100000 = 1.5 ms
# case  1.2s/100000 = 1.2 ms

# Test 1: match exactly one character in class [apz]
# Test 2: added comparison in case of data stream as well

# Case, regex and test are all very elementary commands, and very close in
# run-time. The actual test doesnt matter here, the intent is to look at worse
# case run time before the commands return.
#
# On Bash, both case and Bash's [[ are the fasted, followed by a normal test,
# regex, and finally using a double invocation of test.
#

test_1regex ()
{
  [[ "${1:-abc}" =~ ^[apz]$ ]]
}

test_1test_1 ()
{
  test "${1:-abc}" = "a" -o "${1:-abc}" = "z"
}

test_1test_2 ()
{
  test "${1:-abc}" = "a" || test "${1:-abc}" = "z"
}

test_1testb ()
{
  [[ "${1:-abc}" = "a" || "${1:-abc}" = "z" ]]
}

test_1case ()
{
  case "${1:-abc}" in
      ( a ) true ;;
      ( z ) true ;;
      ( * ) false ;;
  esac
}

test_1grep ()
{
  echo "${1:-abc}" | grep '^[apz]$'
}


testdata_2 ()
{
  # TODO: generate some data?
  set -- /tmp/${0//\//--}.data
  iter=1
  test -e $1 || {
    for x in $(seq 1 $iter)
    do cat ~/bin/*.sh
    done > "$1"
  }

  cat "$1"
}

test_2regex ()
{
  testdata_2 | while read -r data
  do
    test_1regex "$data"
  done
}

test_2test ()
{
  testdata_2 | while read -r data
  do
    test_1test_1 "$data"
  done
}

test_2case ()
{
  testdata_2 | while read -r data
  do
    test_2case "$data"
  done
}

test_2grep ()
{
  testdata_2 | grep '^[apz]$'
}


source tools/benchmark/_lib.sh

echo
echo Test 1: run each test 100x
runs=100
echo -e "\nRunning regex..."; time run_test $runs 1regex
echo -e "\nRunning test (one cmd)..."; time run_test $runs 1test_1
echo -e "\nRunning test (two cmd..."; time run_test $runs 1test_2
echo -e "\nRunning test in Bash..."; time run_test $runs 1testb
echo -e "\nRunning case..."; time run_test $runs 1case

echo
echo Test 1: run each test 1000x
runs=1000
echo -e "\nRunning regex..."; time run_test $runs 1regex
echo -e "\nRunning test (one cmd)..."; time run_test $runs 1test_1
echo -e "\nRunning test (two cmd..."; time run_test $runs 1test_2
echo -e "\nRunning test in Bash..."; time run_test $runs 1testb
echo -e "\nRunning case..."; time run_test $runs 1case

exit
echo
echo Test 2: just compare against grep
runs=1
echo -e "\nRunning regex..."; time run_test $runs 2regex
echo -e "\nRunning test..."; time run_test $runs 2test
echo -e "\nRunning case..."; time run_test $runs 2case
echo -e "\nRunning grep..."; time run_test $runs 2grep

#
