#       1     2    3
# 100x  6.5s  9.4s 7.4s

source tools/benchmark/_lib.sh

runs=100

echo -e "\n1. Demo"
time run_all $runs -- sh_noe $LOG demo
echo -e "\n2. Debug On"
time v=7 run_all $runs -- sh_nerr $LOG debug :key "Descr" "ctx"
echo -e "\n3. Debug Off"
time v=6 run_all $runs -- sh_nerr $LOG debug :key "Descr" "ctx"

#
