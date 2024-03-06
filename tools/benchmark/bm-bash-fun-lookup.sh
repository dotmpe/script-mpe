source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict

lib_load lib-uc sys os str

: "${quiet:=true}"

# Tracking if function exists.

# It is interesting that keeping compgen generated listing in an associative
# array leads to faster benchmarks than using declare. As expected declare runs
# as well as type -t (it will be faster for missing functions as type
# ofcourse checks for others).

# Using an assoc is about 1/3 of declare.

funs=$(compgen -A function)
declare -xf $funs

declare -xA functions
while read -r fun
do functions["$fun"]=
done <<< "$funs"


testcount=1000
testfun=(
  "lib_uc_exists"
  "lib_uc_lib__load"
  "str_word"
  "str_join"
  "str_trim"
  "try_var"
  "sys_set_var"
  "var_assert"
)

arrlookupsh="$TMPDIR/bm-bash-fun-lookup-array.sh"
arrlookup2sh="$TMPDIR/bm-bash-fun-lookup-array2.sh"
dinspectsh="$TMPDIR/bm-bash-fun-lookup-declare.sh"
tinspectsh="$TMPDIR/bm-bash-fun-lookup-type.sh"

{
  "${quiet:?}" ||
  printf 'stderr echo lookup-array ${#functions[@]}\n'
  for i in $(seq 1 $testcount)
  do for tf in ${testfun[@]}
    do printf '[[ "unset" != ${functions["%s"]-unset} ]] &&\n' "$tf"
    done
  done
  "${quiet:?}" && printf 'true\n' ||
  printf 'stderr echo lookup-array done\n'
} >| "$arrlookupsh"

{ cat <<EOM
declare -A functions=()
while read -r fun
do functions["\$fun"]=
done <<< "\$(compgen -A function)" &&
$(for i in $(seq 1 $testcount)
  do for tf in ${testfun[@]}
    do printf '[[ "unset" != ${functions["%s"]-unset} ]] &&\n' "$tf"
    done
  done)
true
EOM
} >| "$arrlookup2sh"

{
  for i in $(seq 1 $testcount)
  do for tf in ${testfun[@]}
    do printf 'declare -F %s >/dev/null &&\n' "$tf"
    done
  done
  "${quiet:?}" && printf 'true\n' ||
  printf 'stderr echo lookup-declare done\n'
} >| "$dinspectsh"

{
  for i in $(seq 1 $testcount)
  do for tf in ${testfun[@]}
    do printf 'type -t %s >/dev/null &&\n' "$tf"
    done
  done
  "${quiet:?}" && printf 'true\n' || printf 'stderr echo lookup-type done\n'
} >| "$tinspectsh"


stderr echo functions: ${#functions[@]}

sample_time 6 bash "$arrlookupsh"
report_time "Array lookup"

sample_time 6 bash "$arrlookup2sh"
report_time "Array gather and lookup"

sample_time 6 bash "$dinspectsh"
report_time "Declare -F lookup"

sample_time 6 bash "$tinspectsh"
report_time "Type -t lookup"
