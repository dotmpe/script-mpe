# bc is about ten times faster than using python

source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict

TMPDIR=/dev/shm/tmp

a=0.001
b=0.005
ffp=6
export a b ffp

declare -A tests=(
  [1-1]='python -c "print( $a + $b )" >>/dev/null'
  [1-2]='echo "scale=$ffp; $a + $b"|bc >>/dev/null'
  [2-1]='python -c "print( $a / $b )" >>/dev/null'
  [2-2a]='echo "scale=$ffp; $a / $b"|bc >>/dev/null'
  [2-2b]='echo "scale=1; $a / $b"|bc >>/dev/null'
  [2-2c]='echo "scale=9; $a / $b"|bc >>/dev/null'
)

testcases=$(printf '%s\n' "${!tests[@]}" | sort -u)

# Multiple tests as GNU time reports in ms precision
# TODO: report actual times, ie run time divided by testcout
testcount=10
# Note sample-count below, which acts as multiplier on this

# Build test scripts (XXX: clean cache by hand when changing testcount/code)
for testcase in $testcases
do
  testexpr=${tests[$testcase]}

  test -s "$TMPDIR/bash-float-math-$testcase.sh" || {
    for i in $(seq 1 $testcount)
    do printf '%s\n' "$testexpr"
    done >| "$TMPDIR/bash-float-math-$testcase.sh"
  }
done

# Execute scripts and sample runtimes
for testcase in $testcases
do
  #echo "$testcase: ${tests[$testcase]}"
  sample_time 10 bash "$TMPDIR/bash-float-math-$testcase.sh"
  report_time "${tests[$testcase]}"
done

# XXX: for pretty table format, try piping to `column -t -s $'\t'`
