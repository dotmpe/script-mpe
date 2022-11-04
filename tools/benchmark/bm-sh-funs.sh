
source tools/benchmark/_lib.sh

test_fun ()
{
  test ${1:?} -eq 0 || test_fun $(( $1 - 1 ))
}

runs=100
recurse=100

# runs recursions time
# 1 100 2ms
# 1 1000 0.1s
# 10 10 1ms
# 10 100 0.13s
# 10 1000 1s
# 100 10 10ms
# 100 100 0.1s
# 100 1000 10s
# 1000 10 95ms
# 1000 100 1.3s

time run_test $runs fun $recurse
