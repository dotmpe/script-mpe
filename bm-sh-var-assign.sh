
# what is faster, var assignment from subshell or using read: subshell
test_subshell()
{
  count=$1
  while test "$count" -gt "0"
  do
    myvar=$(echo myvar)
    count=$(( $count - 1 ))
  done
}
test_read()
{
  count=$1
  while test "$count" -gt "0"
  do
    echo myvar|read myvar
    count=$(( $count - 1 ))
  done
}

runs=1000
echo Testing subshell
time test_subshell $runs
echo Testing read
time test_read $runs



