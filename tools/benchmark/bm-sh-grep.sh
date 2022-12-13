
source tools/benchmark/_lib.sh

runs=1000

test_1a_grep ()
{
  grep -v '^ *\(#.*\)\?$' htd.sh
}

test_1b_egrep ()
{
  grep -Ev '^ *(#.*)?$' htd.sh
}

test_2_ripgrep ()
{
  rg -v '^ *(#.*)?$' htd.sh
}

test_3_silversearcher ()
{
  ag -v '^ *(#.*)?$' htd.sh
}

test_4a_sh ()
{
    while read -r line
    do
        case "$line" in
            ( "" | "# "* ) ;;
            ( * ) echo "$line" ;;
        esac
    done < htd.sh
}

test_4b_sh ()
{
    while IFS=$'\t\n' read -r line_
    do
        line=${line_/[ ]}
        case "$line" in
            ( "" | "# "* ) ;;
            ( * ) echo "$line_" ;;
        esac
    done < htd.sh
}

echo "Grep ($(test_1a_grep | wc -l) lines)"
time run_test_q $runs 1a_grep
echo
echo "Grep -E ($(test_1b_egrep | wc -l) lines)"
time run_test_q $runs 1b_egrep
echo

echo "Rg ($(test_2_ripgrep | wc -l) lines)"
time run_test_q $runs 2_ripgrep
echo

echo "Ag ($(test_3_silversearcher | wc -l) lines)"
time run_test_q $runs 3_silversearcher
echo

echo "Sh (lossy) ($(test_4a_sh | wc -l) lines)"
time run_test_q $runs 4a_sh
echo

echo "Sh ($(test_4b_sh | wc -l) lines)"
time run_test_q $runs 4b_sh
echo

#
