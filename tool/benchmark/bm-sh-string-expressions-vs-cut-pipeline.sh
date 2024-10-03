###

# Sometimes it seems cut is easier. How does it compare speed wise to string
# substitutions.

# path and extension strxpn is easy.
# XXX: show some substitutions with regex and pattern escaping?

# There is some overhead in the testing routines I normally can ignore to do
# rough comparisons of alternative script methods, but for these elementary
# operations they are very relevant.
# XXX: should move these and there are more baselines that would be interesting

# Summary: string expansions vastly outperform pipelines, probably by more than
# 100x (63s vs 0.4s @10k ops is 1:158 ie almost 1.6e100; while @1k was 1:64).
# To get a proper number, the test routines and reporting needs to be profiled
# itself. It looks like about 1/4th of the time for strxpn is spend there.

# But as always, subprocesses are expensive. Especially for single string
# read/substitute/index operations.

myTestPath='path/dir/file?query'

# Just a wrapper for true but still runs remarkably slower than 'bare' command
noop () { :; }

# Get path elements 1-3 into variables, naively using cut-pipeline
test_cut ()
{
  declare p1 p2 p3
  p1=$(echo "$myTestPath" | cut -d '/' -f1)
  p2=$(echo "$myTestPath" | cut -d '/' -f2)
  p3=$(echo "$myTestPath" | cut -d '/' -f3)
  #echo "$p1 $p2 $p3"
}

# Get path elements 1-3 into variables, using string substitution and indexing
test_strxpn ()
{
  declare _p p1 p2 p3
  true "${myTestPath:?}"
  p1=${_//\/*}
  _p=${myTestPath:$(( 1 + ${#p1} ))}
  p2=${_p//\/*}
  _p=${_p:$(( 1 + ${#p2} ))}
  p3=${_p//\/*}
  #echo "$p1 $p2 $p3"
}

source tools/benchmark/_lib.sh

sh_mode strict

# iterations/seconds  (no-op) (true) (sub) (subio)   cut   strxpn
#runs=10 #              0.06   0.06  0.07   0.06     0.13  0.06
#runs=100 #             0.07   0.07  0.07   0.06     0.7   0.07
runs=1000 #             0.08   0.08  0.08   0.07     6.4   0.1
#runs=10000 #           0.19   0.16  0.18   0.23     ~1m   0.4
#runs=100000 #          1.7    1.1   1.2    1.6        -   4.5

# Run four tests to get idea of overhead by testing
time run_test $runs -- noop
time run_test $runs -- true
time run_test_q $runs -- echo
time run_test_q $runs -- echo subio

# Run test functions several times to get better precision for time cost
time run_test $runs cut
time run_test $runs strxpn

#
