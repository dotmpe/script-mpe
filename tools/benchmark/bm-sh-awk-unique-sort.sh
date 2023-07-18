

### Getting unique lines

# This is one scenario where GNU Awk is useful as it outperforms sort in
# run time (and Bash arrays peform very poorly). Having ordered data helps,
# beause uniq is the fastest here, but it is only included out of curiosity.
# Somewhat puzzled by overhad of shell startup vs. other tools but I guess it
# is not surpising.

#             htd.sh       self
# 100x awk      0.9s   0.8   .4
# 100x sort-u   1.3s   1.5   .3
# 100x uniq    ~0.4s    .6   .3
# 100x bash-assoc    >30s   .8

# 10x awk                  .11
# 10x sort-u              >.09
# 10x uniq                <.09
# 10x bash-assoc          >.13
# 10x bash-index          <.34

# Alas, whereas in string cutting shell read loops do very well (see
# bm-sh-last-character-of-line) here such loop does not--looks like Bash assoc
# array lookups suck. Added test using indexed array
# just out of curiosity to compare O(n) with associative array lookup and as it
# should be it does better but the ration is only about 3:1. Test data for for
# this is almost 5k lines of script.


# Using read -r has little effect on performance, but should ensure '\' escaped
# characters remain. Adding IFS ensures whitespace formatting is preserved.
# This test case only differs from awk and sort-u output in that here an empty
# line value is not counted in the current test impl.
test_bash_read_assoc ()
{
  local str len
  typeset -A items
  while IFS=$'\n' read -r str
  do
    test -z "$str" && continue
    test unset != "${items[$str]:-unset}" && continue
    items[${str}]=1
    echo "${str}"
  done
}

# This is O(n)
test_bash_read_index ()
{
  local str len
  typeset -a lines
  IFS=$'\n'
  while read -r str
  do
    for line in "${lines[@]}"
    do
      test "$str" != "$line" && continue || continue 2
    done
    lines+=( "${str}" )
    echo "${str}"
  done
}


test_data ()
{
  cat "${testf:?}"
}

source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict

#true "${testf:=$0}"
true "${testf:=${US_BIN}/htd.sh}"

runs=100
test_data=$(test_data)

report ()
{
  report_time "${1:-$_}" runs=$runs samples=10 load:$(less-uptime g 3) host:$HOST
}


samples=10
test_baseline $samples $runs
report baseline
# baseline		real:.0783	user:.0643	sys:.0261	runs=100	samples=10	load:0.28,0.43,0.54	host:t460s
# XXX: fix reporting for sampler with IO

echo "Test-data: '$testf' ($(wc -l <<< "$test_data") lines)"

echo -e "\nAwk ($(<<< "$test_data" awk '!a[$0]++'|wc -l) lines)"
#sample_time $samples \
time < "$testf" sh_nout run_test_io "" $runs -- awk '!a[$0]++'
#report
#time <<< "$test_data" run_test_io "" $runs -- awk '!a[$0]++'

echo -e "\nSort -u ($(<<< "$test_data" sort -u|wc -l) lines)"
time <<< "$test_data" run_test_io "" $runs -- sort -u

echo -e "\nUniq ($(<<< "$test_data" uniq|wc -l) lines)"
time <<< "$test_data" run_test_io "" $runs -- uniq

echo -e "\nBash read+array-assoc ($(<<< "$test_data" test_bash_read_assoc|wc -l) lines)"
time <<< "$test_data" run_test_io "" $runs -- test_bash_read_assoc

#echo -e "\nBash read+array-index ($(<<< "$test_data" test_bash_read_index|wc -l) lines)"
#time <<< "$test_data" run_test_io "" $runs -- test_bash_read_index

#
