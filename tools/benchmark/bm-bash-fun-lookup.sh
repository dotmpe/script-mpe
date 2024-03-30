source ${US_BIN:=$HOME/bin}/tools/benchmark/_lib.sh
sh_mode strict # dev

lib_load lib-uc sys os str

: "${quiet:=true}"


# Tracking if function exists.

# It is interesting that loading and keeping a compgen generated listing in an
# associative array leads to faster benchmarks than invoking declare or type, to
# test for existence of functions.

# declare -F somehow runs slightly slower than type -t, unexpectedly.
# afaik at least it runs faster for missing functions, which would be expected
# as type ofcourse checks for others as well.

# also unexpected is that expand-aliases seems to have a consistent run-time
# benefit (although tiny), instead of being a penalty

# Current conclusions: using an assoc safes >50% runtime over using declare for
# lookup. declare vs type have barely discernable run-time difference here, but
# declare often does run slightly slower. However it is expected that declare
# will have better run times for false checks.

funs=$(compgen -A function)

testcount=1000
testfun=(
  "lib_uc_exists"
  "lib_uc_lib__load"
  "str_word"
  "str_join"
  "str_trim"
  "absdir"
  "try_var"
  "add_env_path"
  "ziplists"
)

for fun in ${testfun[*]}
do
  sh_fun "$fun" || $LOG error : "No such function" "E$?:$fun" $?
done

# Export all current functions
declare -fx $funs

# Export table with all functions
declare -A functions=()
while read -r fun
do functions["$fun"]=""
done <<< "$funs"

# NOTE: Arrays may have export attribute, but are not actually exported

arrlookupsh="$TMPDIR/bm-bash-fun-lookup-array.sh"
arrlookup2sh="$TMPDIR/bm-bash-fun-lookup-array2.sh"
dinspectsh="$TMPDIR/bm-bash-fun-lookup-declare.sh"
adinspectsh="$TMPDIR/bm-bash-fun-lookup-declare.sh"
tinspectsh="$TMPDIR/bm-bash-fun-lookup-type.sh"
atinspectsh="$TMPDIR/bm-bash-fun-lookup-type-w-aliases.sh"

#sys_debug ||
test -s "$arrlookupsh" ||
{
  "${quiet:?}" ||
    printf 'stderr echo lookup-array ${#functions[@]}\n'
  declare -p functions
  for i in $(seq 1 $testcount)
  do for tf in ${testfun[*]}
    do printf '[[ "${functions["%s"]+set}" ]] &&\n' "$tf"
    done
    printf '# test %i\n' "$i"
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
  do for tf in ${testfun[*]}
    do printf '[[ "unset" != ${functions["%s"]-unset} ]] &&\n' "$tf"
    done
  done)
true
EOM
} >| "$arrlookup2sh"

{
  for i in $(seq 1 $testcount)
  do for tf in ${testfun[*]}
    do printf 'declare -F %s >/dev/null &&\n' "$tf"
    done
  done
  "${quiet:?}" && printf 'true\n' ||
  printf 'stderr echo lookup-declare done\n'
} >| "$dinspectsh"

{
  echo "shopt -s expand_aliases extdebug"
  for i in $(seq 1 $testcount)
  do for tf in ${testfun[*]}
    do printf 'declare -F %s >/dev/null &&\n' "$tf"
    done
  done
  "${quiet:?}" && printf 'true\n' ||
  printf 'stderr echo lookup-declare done\n'
} >| "$adinspectsh"

{
  for i in $(seq 1 $testcount)
  do for tf in ${testfun[*]}
    do printf 'type -t %s >/dev/null &&\n' "$tf"
    done
  done
  "${quiet:?}" && printf 'true\n' || printf 'stderr echo lookup-type done\n'
} >| "$tinspectsh"

{
  echo "shopt -s expand_aliases"
  for i in $(seq 1 $testcount)
  do for tf in ${testfun[*]}
    do printf 'type -t %s >/dev/null &&\n' "$tf"
    done
  done
  "${quiet:?}" && printf 'true\n' || printf 'stderr echo lookup-type done\n'
} >| "$atinspectsh"

scount=5

stderr echo functions: ${#functions[@]}
stderr echo Sampling $testcount runs, $scount times
shopt | stderr grep 'extdebug\|expand_aliases'

sample_time $scount bash "$arrlookupsh"
report_time "Array lookup"

sample_time $scount bash "$arrlookup2sh"
report_time "Array gather and lookup"

sample_time $scount bash "$dinspectsh"
report_time "Declare -F lookup"

sample_time $scount bash "$adinspectsh"
report_time "Declare -F lookup w/ alias expansion enabled"

sample_time $scount bash "$tinspectsh"
report_time "Type -t lookup"

sample_time $scount bash "$atinspectsh"
report_time "Type -t lookup w/ alias expansion enabled"
