# Looking at impact of different subshell to variable captures
# and compare with regular value assignment, etc.

# Best to do normal assignment of course. But using read herestrings is only
# slightly slower and can efficiently get specific pieces of data.

source tools/benchmark/_lib.sh

sh_mode strict

myTestVariable=2e39486d4b881953965441509f9dd13bd0ccab5c62078339abc7ee41db2494d0

normal_assignment ()
{
  str="${myTestVariable}"
}

echo_param_subshell ()
{
  echo "$(echo "${myTestVariable}")"
}

subshell_assignment ()
{
  str=$(echo "${myTestVariable}")
}

read_herestring_normal ()
{
  read -r str <<< "${myTestVariable}"
}

read_herestring_subshell ()
{
  read -r str <<< "$(echo "${myTestVariable}")"
}

iter=1000
export v=5

time run_test_q $iter -- normal_assignment
time run_test_q $iter -- read_herestring_normal
time run_test_q $iter -- echo_param_subshell
time run_test_q $iter -- subshell_assignment
time run_test_q $iter -- read_herestring_subshell
#
