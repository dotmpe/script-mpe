
# A variation on bm-sh-awk-ct-tsv:test-strexpr


# Read is not as fast as a simple string expression. sys time to read is more
# than twice as long.

input_line=word1\ word2\ word3

# Read first word of input line
test_read_word1 ()
{
  local word1 rest
  read -r word1 rest <<< "$input_line"
  echo "$word1"
}

test_strexpr_word1 ()
{
  echo "${input_line/ *}"
}


source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict

report ()
{
  report_time "$_	" samples=10 runs=$iter load:$(less-uptime g 3) host:$HOST
}

iter=1000

for step in $(seq 0 2)
do
sample_time 10 sh_nout run_test $iter -- test_read_word1
report
sample_time 10 sh_nout run_test $iter -- test_strexpr_word1
report
done

# test_read_word1	real:.1429	user:.1081	sys:.0454
# test_strexpr_word1	real:.0849	user:.0709	sys:.0245
# test_read_word1	real:.142	user:.0992	sys:.0536
# test_strexpr_word1	real:.0875	user:.076	sys:.0214
# test_read_word1	real:.1411	user:.1058	sys:.0461
# test_strexpr_word1	real:.088	user:.076	sys:.0224

# test_read_word1		real:.1426	user:.1045	sys:.0489	load:0.83,0.51,0.37
# test_strexpr_word1	real:.0849	user:.0747	sys:.0216	load:0.83,0.51,0.37
# test_read_word1		real:.1463	user:.1014	sys:.0533	load:0.92,0.53,0.37
# test_strexpr_word1	real:.0858	user:.0763	sys:.0205	load:0.92,0.53,0.37
# test_read_word1		real:.1439	user:.1083	sys:.0464	load:0.92,0.53,0.37
# test_strexpr_word1	real:.0881	user:.0714	sys:.0258	load:0.92,0.53,0.37
# test_read_word1		real:.1436	user:.0993	sys:.055	load:0.85,0.52,0.37
# test_strexpr_word1	real:.0836	user:.0714	sys:.0234	load:0.85,0.52,0.37
# test_read_word1		real:.1419	user:.1019	sys:.0509	load:0.85,0.52,0.37
# test_strexpr_word1	real:.0873	user:.076	sys:.0208	load:0.85,0.52,0.37
# test_read_word1		real:.1433	user:.0986	sys:.0552	load:0.94,0.55,0.38
# test_strexpr_word1	real:.0842	user:.0722	sys:.0234	load:0.94,0.55,0.38
# test_read_word1		real:.1413	user:.0981	sys:.0546	load:0.94,0.55,0.38
# test_strexpr_word1	real:.0888	user:.0737	sys:.0235	load:0.94,0.55,0.38
# test_read_word1		real:.1416	user:.1013	sys:.0512	load:0.94,0.56,0.38
# test_strexpr_word1	real:.0839	user:.0737	sys:.0214	load:0.94,0.56,0.38
# test_read_word1		real:.1436	user:.1031	sys:.0511	load:0.94,0.56,0.38
# test_strexpr_word1	real:.0886	user:.0783	sys:.0189	load:0.94,0.56,0.38
# test_read_word1		real:.1418	user:.1044	sys:.0489	load:1.03,0.58,0.39
# test_strexpr_word1	real:.0846	user:.0715	sys:.0241	load:1.03,0.58,0.39

# test_read_word1		real:.15	user:.1084	sys:.0504	samples=10	runs=1000	load:0.66,0.77,0.71
# test_strexpr_word1	real:.0833	user:.0727	sys:.0224	samples=10	runs=1000	load:0.66,0.77,0.71
# test_read_word1		real:.1427	user:.0971	sys:.056	samples=10	runs=1000	load:0.66,0.77,0.71
# test_strexpr_word1	real:.0862	user:.0753	sys:.0215	samples=10	runs=1000	load:0.66,0.77,0.71
# test_read_word1		real:.1494	user:.1123	sys:.0438	samples=10	runs=1000	load:0.69,0.77,0.71
# test_strexpr_word1	real:.0849	user:.0716	sys:.0243	samples=10	runs=1000	load:0.69,0.77,0.71
# test_read_word1		real:.144	user:.1035	sys:.0504	samples=10	runs=1000	load:0.69,0.77,0.71
# test_strexpr_word1	real:.0826	user:.0697	sys:.0244	samples=10	runs=1000	load:0.69,0.77,0.71
# test_read_word1		real:.1501	user:.1005	sys:.0577	samples=10	runs=1000	load:0.79,0.79,0.72
# test_strexpr_word1	real:.0851	user:.0736	sys:.0222	samples=10	runs=1000	load:0.79,0.79,0.72

# test_read_word1		real:.1805	user:.1205	sys:.0603	samples=10	runs=1000	load:0.98,0.86,0.75
# test_strexpr_word1	real:.0969	user:.076	sys:.03		samples=10	runs=1000	load:0.98,0.86,0.75
# test_read_word1		real:.1514	user:.1035	sys:.0541	samples=10	runs=1000	load:1.07,0.88,0.75
# test_strexpr_word1	real:.0949	user:.0813	sys:.0236	samples=10	runs=1000	load:1.07,0.88,0.75
# test_read_word1		real:.1565	user:.1128	sys:.0514	samples=10	runs=1000	load:1.07,0.88,0.75
# test_strexpr_word1	real:.0927	user:.0806	sys:.0227	samples=10	runs=1000	load:1.07,0.88,0.75

# test_read_word1		real:.1485	user:.111	sys:.0476	samples=10	runs=1000	load:0.49,0.61,0.66
# test_strexpr_word1	real:.0891	user:.0798	sys:.0196	samples=10	runs=1000	load:0.49,0.61,0.66
# test_read_word1		real:.1574	user:.1135	sys:.0536	samples=10	runs=1000	load:0.54,0.61,0.66
# test_strexpr_word1	real:.0938	user:.0776	sys:.0246	samples=10	runs=1000	load:0.54,0.61,0.66
# test_read_word1		real:.1543	user:.1161	sys:.0478	samples=10	runs=1000	load:0.54,0.61,0.66
# test_strexpr_word1	real:.0862	user:.0731	sys:.0236	samples=10	runs=1000	load:0.54,0.61,0.66

#
