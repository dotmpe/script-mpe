
### Comparing regex tools

# Looking if GNU grep can be replaced.

# Ripgrep can perform better on large files. Not sure, it may be interesting
# to compare the Linux src test with personal use cases. As for grepping ASCII
# source scripts it looks like grep can easily out-do it, XXX: so need to try
# and turn utf-8 off.

source tools/benchmark/_lib.sh

runs=10

# Tried to get some results but there is too much noise currently on my dev.
# With bench tool a lot of variance (>95%) as well.
# See bm-sh-grep.suite.sh

true "${testf:=htd.sh}"
bre='^ *\(#.*\)\?$'
re='^ *(#.*)?$'

# Max. resamples
bench_opt="--resamples 1000000"


test_1a_grep ()
{
  LC_ALL="en_US.utf-8" grep -v "$bre" "${testf:?}"
}

test_1a2_grep_C ()
{
  LC_ALL=C grep -v "$bre" "${testf:?}"
}

test_1b_egrep ()
{
  grep -Ev "$re" "${testf:?}"
}

test_1b2_egrep_C ()
{
  LC_ALL=C grep -Ev "$re" "${testf:?}"
}

test_2a_ripgrep ()
{
  rg -v "$re" "${testf:?}"
}

test_2b1_ripgrep_C ()
{
  LC_ALL=C rg -v "$re" "${testf:?}"
}

test_2b2_ripgrep ()
{
  rg -j1 -uuu -v "$re" "${testf:?}"
}

test_2b3_ripgrep ()
{
  rg -v "$re" "${testf:?}"
}

# XXX: tweak options/env?
test_3_silversearcher ()
{
  ag -v "$re" "${testf:?}"
}




## 1. grep


run ()
{
echo "Grep ($(test_1a_grep | wc -l) lines)"
#time sh_null test_1a_grep
#time sh_null run_test $runs 1a_grep
#time sh_null run_test 10 1a_grep
bench ${bench_opt:-} "$(funbody test_1a_grep)" --output test_1a_grep.html
echo

echo "Grep ($(test_1a2_grep_C | wc -l) lines)"
#time sh_null test_1a2_grep_C
#time sh_null run_test $runs 1a2_grep_C
bench ${bench_opt:-} "$(funbody test_1a2_grep_C)" --output test_1a2_grep_C.html
echo

echo "Grep -E ($(test_1b_egrep | wc -l) lines)"
#time sh_null test_1b_egrep
#time sh_null run_test $runs 1b_egrep
bench ${bench_opt:-} "$(funbody test_1b_egrep)" --output test_1b_egrep.html
echo

echo "Grep -E ($(test_1b2_egrep_C | wc -l) lines)"
#time sh_null test_1b2_egrep_C
#time sh_null run_test $runs 1b2_egrep_C
bench ${bench_opt:-} "$(funbody test_1b2_egrep_C)" --output test_1b2_egrep_C.html
echo


## 2. ripgrep

echo "Rg (C)($(test_2b1_ripgrep_C | wc -l) lines)"
#time sh_null test_2b1_ripgrep_C
#time sh_null run_test $runs 2b1_ripgrep_C
bench ${bench_opt:-} "$(funbody test_2b1_ripgrep_C)" --output test_2b1_ripgrep_C.html
echo

echo "Rg -j1 -uuu ($(test_2b2_ripgrep | wc -l) lines)"
#time sh_null test_2b2_ripgrep
#time sh_null run_test $runs 2b2_ripgrep
bench ${bench_opt:-} "$(funbody test_2b2_ripgrep)" --output test_2b2_ripgrep.html
echo

echo "Rg ($(test_2b3_ripgrep | wc -l) lines)"
#time sh_null test_2b3_ripgrep
#time sh_null run_test $runs 2b3_ripgrep
bench ${bench_opt:-} "$(funbody test_2b3_ripgrep)" --output test_2b3_ripgrep.html
echo


#echo "Ag ($(test_3_silversearcher | wc -l) lines)"
#time sh_null run_test $runs 3_silversearcher
#echo

#re='\w+\s+Холмс\s+\w+'
#
#echo "2. Grep -E ($(test_1b_egrep | wc -l) lines)"
#time sh_null test_1b_egrep
##time sh_null run_test $runs 1b_egrep
#echo
#
#echo "2. Rg ($(test_2_ripgrep | wc -l) lines)"
#time sh_null test_2_ripgrep
##time sh_null run_test $runs 2_ripgrep
#echo
}

case "$(basename -- "$0" .sh)" in

  ( bm-sh-grep ) run ;;

  ( * )
      case "${1:-}" in
        ( test_* ) "$1" ;;
      esac
    ;;
esac
#
