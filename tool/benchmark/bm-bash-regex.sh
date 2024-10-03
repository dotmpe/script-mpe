# Testing regexes, just out of curiosity how expr performs. Its almost as bad
# as using grep.

source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict

declare -A tests_regex=(
  [1]='expr "$a" : "^[A-Za-z_]*$" >/dev/null'
  [2]='[[ $a =~ ^[A-Za-z_]*$ ]]'
  [3]='echo "$a" | grep -q "^[A-Za-z_]*$"'
  [3b]='<<< "$a" grep -q "^[A-Za-z_]*$"'
)

a=foobar

declare -n tests=tests_regex
#declare -A tests
#lib_require sys
#assoc_concat tests $(compgen -A arrayvar tests_)

testcases=$(printf '%s\n' "${!tests[@]}" | sort -u)
testcount=100
# Build test scripts (XXX: clean cache by hand when changing testcount/code)
for testcase in $testcases
do
  testexpr=${tests[$testcase]}

  test -s "$TMPDIR/bash-test-$testcase.sh" || {
    for i in $(seq 1 $testcount)
    do printf '%s\n' "$testexpr"
    done >| "$TMPDIR/bash-test-$testcase.sh"
  }
done

# Execute scripts and sample runtimes
for testcase in $testcases
do
  sample_time 10 bash "$TMPDIR/bash-test-$testcase.sh"
  report_time "${tests[$testcase]}"
done
