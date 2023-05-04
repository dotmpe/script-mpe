
. ${US_BIN:=${HOME:?}/bin}/tools/benchmark/_lib.sh

runs=100

echo "p{1,1}" >&2
# The native bash solution p2 looks a bit faster
time run_test_q 100 -- less-uptime p1
time run_test_q 100 -- less-uptime p2

echo "l{1,1}" >&2
# Again native Bash spends less CPU time for user or sys
time run_test_q 100 -- less-uptime l1
time run_test_q 100 -- less-uptime l2

#time run_test_q 100 -- less-uptime g
