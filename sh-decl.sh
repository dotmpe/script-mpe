
## Shell/decl: track shell declarations for more optimal type handling

# Test, what is faster e.g. to check for array/Array type?
# Look at speed implications for each method.

# A. process opts from `typeset -p` output, or
# B. 1. store opts in one assoc arr, or
# B. 2. one array for each opt, or
# C. use standard simple variables using variable name keying

# Numbers below. Observations:
# Surprised the `typeset -p` subshell has this large an impact compared to
# case/esac. And clearly caching improves runtime more than one order
# of magnitude. Associative arrays showing a tiny but noticable improvement
# over regular variables (most or all of the times).

# Did not do test B.2 because it seems like it would be worse than either B
# or C anyway, as case/esac has little impact and B.2. would double 'access
# time' to get rid of just the opts matching...

# See also other previous benchmarks:
#
# - tools/bookmark/bm-sh-type.sh
#   how typeset -F is a superior check for types (0.1us on t460s vs. 450 microseconds for type -t plus str cmp).
#
# - tools/benchmark/bm-sh-regex-case.sh
#   compare regex vs. case/esac string matching (1.7 vs 1.2 ms @t460s)
#   Even test is (a bit) slower (1.5ms).
#
# - tools/benchmark/bm-sh-test.sh (test -n "str" runs in 9us @t460s)

# Conclusion: some of these numbers need review because I'm not sure all adds
# up. But probably want to review more automatic profiling method, etc.

# Regardless, numbers are very favorable towards:
#
# 1. as little subshells as needed (what else is new...)
# 2. better arrays than classical variables with magic names, but either is not
#    bad. At least because here the symbols are already variable names
#    so they need no further encoding to use as 'key'.
# 3. case/esac wins for simple str match, same as other string expansions.
#
# And I think regex (don't forget BASH_REMATCH) easily outperforms any
# external program but that is just an semi-informed opinion atm. Need to do
# some testing of regex builtin vs. grep/awk/sed/perl/ag/rg/... some day
# but regex'ing is not too important right away.


source tools/benchmark/_lib.sh

sh_mode strict

# A. 10000 x ~<8s
# B. 10000 x 0.4s
# C. 10000 x >0.4s

runs=10000

myTestVariable=2e39486d4b881953965441509f9dd13bd0ccab5c62078339abc7ee41db2494d0

read_decl ()
{
  read -r dname dopts decl <<< "$(declare -p "${1:?}")"
}

is_assoc_arr ()
{
  case "${1:1}" in ( *A* ) true ;; ( * ) false ;; esac
}

is_index_arr ()
{
  case "${1:1}" in ( *a* ) true ;; ( * ) false ;; esac
}

is_arr ()
{
  is_assoc_arr "$dopts" || is_index_arr "$dopts"
}

test_A_raw ()
{
  read_decl "$1"
  is_arr "$dopts"
}

typeset -A my_b_cache

test_B_cache_arr ()
{
  test "${my_b_cache["$1"]-unset}" = "unset" && {
    read_decl "$1"
    my_b_cache["$1"]=$dopts
  } || {
    dopts=${my_b_cache["$1"]}
  }
  is_arr "$dopts"
}

test_C_cache_vars ()
{
  typeset var="${1:?}_opts"
  test "${!var-unset}" = "unset" && {
    read_decl "$1"
    typeset -g "${1:?}_opts=$dopts"
  } || {
    dopts=${!var}
  }
  is_arr "$dopts" || true
}

test_C_is_working ()
{
  test_C_cache_vars myTestVariable
  echo n:$dname $dopts d:$decl
  unset dname dopts decl
  test_C_cache_vars myTestVariable
  echo n:${dname:-unset} ${dopts:-unset} d:${decl:-unset}
}

time run_test $runs -- test_A_raw myTestVariable
time run_test $runs -- test_B_cache_arr myTestVariable
time run_test $runs -- test_C_cache_vars myTestVariable

#
