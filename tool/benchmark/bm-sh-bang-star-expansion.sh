## How to get all varnames

# Is expansion still fasted when looking for all variables?

# ${!var*} does not do dynamic names, so it always requires a prefix.

# These actually all perform about the same. String parameter expansion is only
# marginally (maybe a few percent or so) better than the two pipelines.
# And, the expansion trick also lists some of the internal BASH variables which
# neither declare or set lists (by default? but don't know of any option)

# Update: case D. 'compgen -v' performs even better.

# A. ~0.22s ( / 100 = 2.3ms )
# B. ~0.23s
# C. ~0.23s
# D. ~0.03s


test_all_varnames_A_expand ()
{
  eval echo '${!'{{a..z},{A..Z},_}'*}'
}

test_all_varnames_B_declare ()
{
  declare | grep_keys
}

test_all_varnames_C_set ()
{
  set | grep_keys
}

test_all_varnames_D_compgen ()
{
  compgen -v
}

grep_keys ()
{
  grep -oP '^\K[[:alnum:]_]+(?==)'
}

echo A.
test_all_varnames_A_expand | tr ' ' '\n' | sort -u | tr '\n' ' '
echo
test_all_varnames_A_expand | tr ' ' '\n' | sort -u | wc -l
test_all_varnames_A_expand | wc -w

echo B.
test_all_varnames_B_declare | sort -u | tr '\n' ' '
echo
test_all_varnames_B_declare | sort -u | wc -l
test_all_varnames_B_declare | wc -w

echo C.
test_all_varnames_C_set | sort -u | tr '\n' ' '
echo
test_all_varnames_C_set | sort -u | wc -l
test_all_varnames_C_set | wc -w

echo D.
test_all_varnames_D_compgen | sort -u | tr '\n' ' '
echo
test_all_varnames_D_compgen | sort -u | wc -l
test_all_varnames_D_compgen | wc -w

source tools/benchmark/_lib.sh

runs=100

time run_test_q $runs all_varnames_A_expand
time run_test_q $runs all_varnames_B_declare
time run_test_q $runs all_varnames_C_set
time run_test_q $runs all_varnames_D_compgen
