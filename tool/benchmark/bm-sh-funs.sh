
source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict

# Not much to say about this. See benchmark/baseline@dev

test_fun ()
{
  test ${1:?} -eq 0 || test_fun $(( $1 - 1 ))
}

# runs recursions time
# 1 100 2ms
# 1 1000 0.1s
# 10 10 1ms
# 10 100 0.13s
# 10 1000 1s
# 100 10 10ms
# 100 100 0.1s
# 100 1000 10s
# 1000 10 95ms
# 1000 100 1.3s

report ()
{
  report_time "${1:-$_}" recurse=$recurse runs=$runs samples=$samples \
      load:$(less-uptime g 3) host:$HOST
}

runs=100
recurse=100

time run_test $runs fun $recurse
time run_test $runs -- test_fun $recurse

samples=10

for recurse in 1 10 100
do
  for runs in 1 10 100 1000
  do
    test_baseline $samples $runs test_fun $recurse
    report "fun"
  done
done

# fun	real:.0719	user:.06	sys:.0209	recurse=100 runs=1 samples=10 load:0.62, 0.55, 0.65 host:t460s
# fun	real:.0975	user:.0819	sys:.0265	recurse=100 runs=10 samples=10 load:0.62, 0.55, 0.65 host:t460s
# fun	real:.2046	user:.1953	sys:.0207	recurse=100 runs=100 samples=10 load:0.62, 0.55, 0.65 host:t460s
# fun	real:1.5265	user:1.51	sys:.024	recurse=100 runs=1000 samples=10 load:0.77, 0.59, 0.66 host:t460s

# fun	real:.0765	user:.0659	sys:.0221	recurse=100 runs=1 samples=10 load:0.15, 0.29, 0.27 host:t460s
# fun	real:.0922	user:.0735	sys:.0297	recurse=100 runs=10 samples=10 load:0.15, 0.29, 0.27 host:t460s
# fun	real:.2482	user:.2357	sys:.0234	recurse=100 runs=100 samples=10 load:0.21, 0.30, 0.28 host:t460s
# fun	real:1.6109	user:1.5955	sys:.0245	recurse=100 runs=1000 samples=10 load:0.39, 0.34, 0.29 host:t460s

# fun	real:.0683	user:.0572	sys:.0229	recurse=100 runs=1		amples=10	load:0.35,0.36,0.30 host:t460s
# fun	real:.0821	user:.0709	sys:.0218	recurse=100 runs=10		amples=10	load:0.35,0.36,0.30 host:t460s
# fun	real:.2088	user:.1959	sys:.0226	recurse=100 runs=100	samples=10	load:0.41,0.37,0.30 host:t460s
# fun	real:1.6348	user:1.6104	sys:.0244	recurse=100 runs=1000	samples=10	load:0.54,0.40,0.31 host:t460s

# fun	real:.0691	user:.0582	sys:.0222	recurse=100	runs=1	    samples=10	load:0.29,0.52,0.61	host:t460s
# fun	real:.0828	user:.0706	sys:.0238	recurse=100	runs=10	    samples=10	load:0.35,0.53,0.62	host:t460s
# fun	real:.2102	user:.201	sys:.0201	recurse=100	runs=100	samples=10	load:0.35,0.53,0.62	host:t460s
# fun	real:1.6291	user:1.6084	sys:.0261	recurse=100	runs=1000	samples=10	load:0.56,0.57,0.63	host:t460s

# Did reorder this (by recurse), so load is out of sequence.
# fun	real:.077	user:.0632	sys:.0256	recurse=1	runs=1		samples=10	load:0.75,0.73,0.69	host:t460s
# fun	real:.0758	user:.0638	sys:.0239	recurse=1	runs=10		samples=10	load:0.75,0.73,0.69	host:t460s
# fun	real:.077	user:.0627	sys:.0276	recurse=1	runs=100	samples=10	load:0.77,0.73,0.69	host:t460s
# fun	real:.1061	user:.092	sys:.0257	recurse=1	runs=1000	samples=10	load:0.87,0.76,0.70	host:t460s
# fun	real:.0763	user:.0638	sys:.0242	recurse=10	runs=1		samples=10	load:0.75,0.73,0.69	host:t460s
# fun	real:.0806	user:.0654	sys:.0249	recurse=10	runs=10		samples=10	load:0.77,0.73,0.69	host:t460s
# fun	real:.0885	user:.0725	sys:.0276	recurse=10	runs=100	samples=10	load:0.77,0.73,0.69	host:t460s
# fun	real:.1915	user:.1726	sys:.0306	recurse=10	runs=1000	samples=10	load:0.87,0.76,0.70	host:t460s
# fun	real:.0767	user:.0639	sys:.0249	recurse=100	runs=1		samples=10	load:0.75,0.73,0.69	host:t460s
# fun	real:.0908	user:.077	sys:.0258	recurse=100	runs=10		samples=10	load:0.77,0.73,0.69	host:t460s
# fun	real:.2398	user:.2201	sys:.0276	recurse=100	runs=100	samples=10	load:0.87,0.76,0.70	host:t460s
# fun	real:1.8551	user:1.805	sys:.0532	recurse=100	runs=1000	samples=10	load:1.07,0.81,0.72	host:t460s

#
