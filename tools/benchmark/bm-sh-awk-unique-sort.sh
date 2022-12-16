

### Getting unique lines

# This is one scenario where GNU Awk is useful as it outperforms sort in
# run time. Having ordered data also helps, uniq is the fastest here.

# 100x awk 0.9s
# 100x sort-u 1.3s
# 100x uniq ~0.4s

test_data ()
{
  cat "${testf:?}"
}

source tools/benchmark/_lib.sh

true "${testf:=htd.sh}"
echo "Test-data: '$testf' ($(wc -l < "$testf") lines)"

runs=100

echo -e "\nAwk ($(awk '!a[$0]++' "${testf:?}" | wc -l) lines)"
time run_test_io "" $runs -- awk '!a[$0]++'
echo -e "\nSort -u ($(sort -u "${testf:?}" | wc -l) lines)"
time run_test_io "" $runs -- sort -u
echo -e "\nUniq ($(uniq "${testf:?}" | wc -l) lines)"
time run_test_io "" $runs -- uniq

#
