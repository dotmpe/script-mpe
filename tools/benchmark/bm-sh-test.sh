
source tools/benchmark/_lib.sh

runs=100000

# 1000 9ms
# 10000 100ms
# 100000 1s   (hundred thousand)
# 1000000 11s (one million)

# So extrapolating from lowest reported time interval gives about
# 1 call takes 9 us (t460s)

time run_test $runs -- test -n "str"
