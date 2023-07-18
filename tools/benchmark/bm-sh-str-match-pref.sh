
# Looking at how fast a regex test does for a simple two-char check.

# regex 1.7s/100000 = 1.7 ms
# test  1.5s/100000 = 1.5 ms
# case  1.2s/100000 = 1.2 ms

# Test 1: match exactly one character in class [az]
# Test 2: added comparison in case of data stream as well

test_1regex ()
{
  [[ "abc" =~ ^[az]$ ]]
}

test_1test ()
{
  #test "abc" = "a" -o "abc" = "z"
  test "abc" = "a" || test "abc" = "z"
}

test_1case ()
{
  case "abc" in
      ( a ) true ;;
      ( z ) true ;;
      ( * ) false ;;
  esac
}

test_1grep ()
{
  echo "abc" | grep '^[az]$'
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
    [[ "$data" =~ ^[az]$ ]]
  done
}

test_2test ()
{
  testdata_2 | while read -r data
  do
    test "$data" = "a" || test "$data" = "z"
  done
}

test_2case ()
{
  testdata_2 | while read -r data
  do
    case "$data" in
        ( a ) true ;;
        ( z ) true ;;
        ( * ) false ;;
    esac
  done
}

test_2grep ()
{
  testdata_2 | grep '^[az]$'
}


source tools/benchmark/_lib.sh

echo
echo Test 1
runs=100
echo -e "\nRunning regex..."; time run_test $runs 1regex
echo -e "\nRunning test..."; time run_test $runs 1test
echo -e "\nRunning case..."; time run_test $runs 1case
#echo -e "\nRunning grep..."; time run_test 100 1grep

echo
echo Test 2
runs=1
echo -e "\nRunning regex..."; time run_test $runs 2regex
echo -e "\nRunning test..."; time run_test $runs 2test
echo -e "\nRunning case..."; time run_test $runs 2case
echo -e "\nRunning grep..."; time run_test $runs 2grep

#
