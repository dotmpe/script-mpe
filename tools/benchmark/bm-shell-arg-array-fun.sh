source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict


set -- sys-cmd args
lib_require "$@" &&
lib_init  "$@"

argvr_arr () # ~ <Arr> <Items...>
{
  declare -n __arr=${1:?}
  local _c_
  for (( _c_=$#; _c_>1; _c_-- ))
  do
    __arr+=( "${!_c_}" )
  done
}


declare -xa foo
declare -xa args=(
  sdfsdfewwe
  erwfjhsdfjh
  wefkhjelwk
  wkljeflhfwv
  wfekljsdfklh
  sdlkjfweoihfw
  sdf
  weflkjwfoih
  qopihvqihje
  lksdhoihsdfoih
  wefiwvoivw
  sdoiwoihec
  lkzdoihvsh
  wefikacosinc
  aocinc
  eoincdso
  ljasiljdqwo
  aclskjasdlj
)
declare -fx argvr_arr sys_arra

declare -A tests_bash_test=(
  [1-1]='foo=(); argvr_arr foo "${args[@]}"'
  [1-2]='foo=(); sys_arra foo "${args[@]}"'
  [1-3]='foo=( "${args[@]}" )'
)

declare -n tests=tests_bash_test

testcases=$(printf '%s\n' "${!tests[@]}" | sort -u)

# Multiple tests as GNU time reports in ms precision
# TODO: report actual times, ie run time divided by testcout
testcount=1000
# Note sample-count below, which acts as multiplier on this

# Build test scripts (XXX: clean cache by hand when changing testcount/code)
for testcase in $testcases
do
  testexpr=${tests[$testcase]}

  test -s "$TMPDIR/shell-arg-array-fun-$testcase.sh" || {
    for i in $(seq 1 $testcount)
    do printf '%s\n' "$testexpr"
    done >| "$TMPDIR/shell-arg-array-fun-$testcase.sh"
  }
done

# Execute scripts and sample runtimes
for testcase in $testcases
do
  #echo "$testcase: ${tests[$testcase]}"
  sample_time 100 bash "$TMPDIR/shell-arg-array-fun-$testcase.sh"
  report_time "${tests[$testcase]}"
done
