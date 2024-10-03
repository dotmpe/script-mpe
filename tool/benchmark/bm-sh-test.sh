
source tools/benchmark/_lib.sh

runs=10000

time run_test $runs -- test 0 -gt 1
time run_test $runs -- test -n "str"
time run_test $runs -- test "str" = "foo"
