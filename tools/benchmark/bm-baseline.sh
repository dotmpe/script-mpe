
# Some numbers of using bm:lib run-test and run-test-io with noop, and looking
# at a few methods of writing no-op commands.

# I tried to keep the system free of tasks but did not close down much, still
# the sys column is fairly consistent. Included pause finally as well to try
# to recover from system load at high sample/run counts. Still, its hard to
# separate shell setup from actual command for a use-case like this.

# Need/want much better but this is the state of bm:lib currently.
# See benchmark/baseline@dev

# TODO: compare run-test-io

# @t460s at 10/10 samples/runs:
# true              real:.0803 user:.0644 sys:.026
# false             real:.0794 user:.0619 sys:.0231
# :                 real:.0717 user:.0587 sys:.0248
# printf            real:.0852 user:.0667 sys:.0267
# echo-n            real:.0725 user:.0586 sys:.0255
# cat-null          real:.0841 user:.0645 sys:.0304

# @t460s at 100/10 samples/runs:
# true              real:.07137 user:.06003 sys:.02081
# false             real:.06999 user:.05882 sys:.0214
# :                 real:.0717  user:.0595  sys:.02165
# printf            real:.07192 user:.0607  sys:.02065
# echo-n            real:.06928 user:.05856 sys:.02146
# cat-null          real:.08123 user:.06701 sys:.02453

# @t460s at 100/10 samples/runs:
# true              real:.0705  user:.05836 sys:.02253
# false             real:.07168 user:.06043 sys:.02155
# :                 real:.07122 user:.05871 sys:.0224
# printf            real:.07214 user:.0592  sys:.02247
# echo-n            real:.07203 user:.06077 sys:.02076
# cat-null          real:.08047 user:.06788 sys:.02364
# noopfun           real:.07178 user:.05929 sys:.02212
# fun_strkeeparg    real:.0709  user:.0593  sys:.02203
# fun_strarg        real:.07183 user:.05972 sys:.02237

# @t460s at 100/10 samples/runs:
# true              real:.088   user:.0648  sys:.0296
# false             real:.0679  user:.0584  sys:.0208
# :                 real:.0766  user:.0609  sys:.0255
# printf            real:.0683  user:.0602  sys:.0193
# echo-n            real:.0723  user:.0644  sys:.0186
# cat-null          real:.1667  user:.1344  sys:.0452
# noopfun           real:.071   user:.0622  sys:.0195
# fun_strkeeparg    real:.0687  user:.056   sys:.0242
# fun_strarg        real:.069   user:.0621  sys:.0184

# @t460s at 100/1000 samples/runs:
# true             real: .0831  user:.0688  sys:.0221
# false            real: .0858  user:.0694  sys:.0275
# :                real: .0751  user:.0641  sys:.0223
# printf           real: .0902  user:.0727  sys:.0262
# echo-n           real: .0755  user:.0694  sys:.0174
# cat-null         real:1.0526  user:.7976  sys:.3039
# noopfun          real: .0857  user:.065   sys:.0268
# fun_strkeeparg   real: .0806  user:.0695  sys:.022
# fun_strarg       real: .0865  user:.0763  sys:.0197

noopfun () { :; }
fun_strkeeparg () { : "$_"; }
fun_strarg () { : "${1:-}"; }

source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict

test_report ()
{
  report_time "${1:-$_}" samples=$samples runs=$runs load:$(less-uptime g 3) host:$HOST
  ${pause:+sleep $pause}
}
# enable to give some more $LOG output, or set to false to skip all $LOG
#quiet=false

# Warm-up
time run_test 1000000 -- true
time run_test 10000 -- true
time run_test 100 -- true
time run_test 1 -- true

runs=1000
samples=10
pause=10
test_baseline $samples $runs true
test_report
test_baseline $samples $runs false
test_report
test_baseline $samples $runs :
test_report
test_baseline $samples $runs printf ''
test_report printf"		"
test_baseline $samples $runs echo -n ''
test_report echo-n"		"
# Not possible, null isnt a loadable executable.
#test_baseline $samples $runs /dev/null
#sample_report exec-null
test_baseline $samples $runs cat /dev/null
test_report cat-null
test_baseline $samples $runs noopfun
test_report
test_baseline $samples $runs fun_strkeeparg
test_report fun_strkeeparg
test_baseline $samples $runs fun_strarg arg
pause= test_report fun_strarg

# true				real:.1825		user:.1572	sys:.0364	samples=10	runs=10000	load:0.38,0.61,0.63	host:t460s
# false				real:.1992		user:.17	sys:.0377	samples=10	runs=10000	load:0.38,0.59,0.63	host:t460s
# :					real:.457		user:.2352	sys:.0534	samples=10	runs=10000	load:0.69,0.65,0.65	host:t460s
# printf			real:.1873		user:.1593	sys:.0352	samples=10	runs=10000	load:1.07,0.73,0.67	host:t460s
# echo-n			real:.1925		user:.1659	sys:.0388	samples=10	runs=10000	load:0.90,0.70,0.66	host:t460s
# cat-null			real:11.3765	user:8.3528	sys:3.4732	samples=10	runs=10000	load:1.65,1.09,0.82	host:t460s
# noopfun			real:.2175		user:.1915	sys:.0349	samples=10	runs=10000	load:1.43,1.07,0.82	host:t460s
# fun_strkeeparg	real:.2349		user:.2031	sys:.0434	samples=10	runs=10000	load:1.21,1.03,0.81	host:t460s
# fun_strarg		real:.2435		user:.2186	sys:.0376	samples=10	runs=10000	load:1.10,1.01,0.80	host:t460s

# true				real:.0881	user:.0737	sys:.0274	samples=10	runs=1000	load:0.36,0.46,0.61	host:t460s
# false				real:.1074	user:.0824	sys:.0321	samples=10	runs=1000	load:0.44,0.47,0.61	host:t460s
# :					real:.0916	user:.075	sys:.0271	samples=10	runs=1000	load:0.44,0.47,0.61	host:t460s
# printf			real:.0908	user:.0747	sys:.028	samples=10	runs=1000	load:0.37,0.45,0.60	host:t460s
# echo-n			real:.0886	user:.0743	sys:.0262	samples=10	runs=1000	load:0.32,0.44,0.59	host:t460s
# cat-null			real:1.1571	user:.8653	sys:.3685	samples=10	runs=1000	load:0.36,0.44,0.59	host:t460s
# noopfun			real:.0976	user:.0784	sys:.0297	samples=10	runs=1000	load:0.30,0.42,0.58	host:t460s
# fun_strkeeparg	real:.0932	user:.0799	sys:.0248	samples=10	runs=1000	load:0.41,0.44,0.59	host:t460s
# fun_strarg		real:.0958	user:.0776	sys:.0303	samples=10	runs=1000	load:0.43,0.44,0.59	host:t460s

#
