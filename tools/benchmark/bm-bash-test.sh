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
#testcount=100

declare -gxA FOO=(
  [mykey]=""
)

local_xxx ()
{
  local xxx=123
}
declare -xf local_xxx fun_{true,stat,keep{,1}}

# Shows that [[ ... ]] is prefarable to [ (alias test),
declare -A tests_bash_test=(
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

#declare -A tests_args_iter=(
#  [4-1]='for a in $(seq 1 15); do :;done'
#  [4-2]='set -- $(seq 1 15); for a; do :;done'
#  [4-3]='set -- $(seq 1 15); mapfile -t args <<< "${_// /\n}"; for a in "${args[@]}"; do :;done'
#)

# To inspect functions (like variables and other keywords/builtin commands)
# declare or type -t must be used, which are fairly slow compared to other
# regular shell ops and commands
declare -A tests_var_inspect=(
  [5-1]='declare -p xxx 2>/dev/null'
  #[5-1b]='if_ok "$(declare -p xxx 2>/dev/null)"'
  [5-1c]='std_quiet declare -p xxx'
  [5-2]='[[ "unset" != "${declare-unset}" ]]'
  [5-2b]='test "unset" != "${declare-unset}"'

  [6-1]='declare xxx=123'
  [6-2]='xxx=123'
  [6-3]='local_xxx'
  [6-4]='declare -g xxx=123'
)
declare -A tests_fun_inspect=(
  #[7-1]='type -t lib_load'
  #[7-1b]='declare -F lib_load'
  #[7-1c]='declare -f lib_load'
  [7-2a]='std_quiet type -t lib_load'
  [7-2b]='std_quiet declare -f lib_load'
  [7-2c]='std_quiet declare -F lib_load'
  [7-1b]='std_quiet type -t xxxx'
  [7-2b]='std_quiet declare -F xxxx'
  # Just calling function and checking for E:nf=127 is easily ten times as fast
  # as type -t and about 4 times faster than declare
  [7-3]='std_quiet xxxxxxx'
)
declare -A tests_arr_inspect=(
  [7-3]='[[ "unset" != "${FOO[mykey]-unset}" ]]'
  [7-3b]='[[ "unset" != "${FOO[otherkey]-unset}" ]]'
)
declare -A tests_fun_rt=(
  [8-1]=':'
  [8-2]='fun_true'
  [8-3]='fun_stat'
  [8-4]='fun_keep1'
  [8-5]='fun_keep'
)
# Compare with fs/filetable reads
declare -A tests_fstat=(
#  [9-0]='/bin/true' # two orders slower, ie. not what bash is actually running
  [9-0b]='true'
#  [9-1]='std_quiet stat main.rst' # runs two order slower than others
  [9-2]='test -e main.rst'
  [9-2b]='test ! -e default.rst'
  [9-2c]='[[ -e main.rst ]]'
  [9-2d]='[[ ! -e default.rst ]]'
  [9-3]='test -d tools'
  [9-3b]='[[ -d tools ]]'
)

declare -A tests
assoc_concat tests $(compgen -A arrayvar tests_)

testcases=$(printf '%s\n' "${!tests[@]}" | sort -u)

# Multiple tests as GNU time reports in ms precision
# TODO: report actual times, ie run time divided by testcout
testcount=1000
# Note sample-count below, which acts as multiplier on this

# Build test scripts
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
  #echo "$testcase: ${tests[$testcase]}"
  sample_time 10 bash "$TMPDIR/bash-test-$testcase.sh"
  report_time "${tests[$testcase]}"
done

# XXX: for pretty table format, try piping to `column -t -s $'\t'`
