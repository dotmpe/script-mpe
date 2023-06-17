source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict

# Comparing test vs. bash [[
# Added [ which should be same as test.
# Do not expect much difference or [[ being slower.
# It is hard to measure, and the sys column does not display any clear
# deviation. The numbers are all in the same ballpark and all vary just as
# much.

# But there is a consistently lower time spent for [[ in the user/real time
# columns. Could be as much as around 1/4th improvement.

TMPDIR=/dev/shm/tmp

testcount=10000

declare -A tests=(
  [1-1]='[ 1 \> 0 ]'
  [1-1b]='[ 1 -gt 0 ]'
  [1-2]='[ foo = bar ]'

  [2-1]='test 1 \> 0'
  [2-1b]='test 1 -gt 0'
  [2-2]='test foo = bar'

  [3-1]='[[ 1 > 0 ]]'
  [3-1b]='[[ 1 -gt 0 ]]'
  [3-2]='[[ foo = bar ]]'
)

testcases=$(printf '%s\n' "${!tests[@]}" | sort -u)

for testcase in $testcases
do
  testexpr=${tests[$testcase]}
  for i in $(seq 1 $testcount)
  do printf '%s\n' "$testexpr"
  done >"$TMPDIR/bash-test-$testcase.sh"
done

for testcase in $testcases
do
  #echo "$testcase: ${tests[$testcase]}"
  sample_time 10 bash "$TMPDIR/bash-test-$testcase.sh"
  report_time "${tests[$testcase]}"
done
