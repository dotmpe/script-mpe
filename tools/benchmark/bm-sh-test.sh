
source tools/benchmark/_lib.sh

runs=100000

# 1000 9ms
# 10000 100ms
# 100000 1s
# 1000000 11s

# So extrapolating lowest measurable gives about
# 1 call 9 us

time run_test $runs -- test -n "null"
