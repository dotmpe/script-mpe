


count=10000

myfunc()
{
  return 0
}
myfunc2()
{
  myfunc "$@"
}
myfunc3()
{
  ( myfunc "$@" )
}
myfunc4()
{
  { myfunc "$@"; }
}



runner()
{
  c=0
  time while true; do c=$(( $c + 1 )); $@; test $c -eq $count && break; done
}

timer()
{
  runner $@ 2>&1 | grep real | sed 's/.*0m\([0-9]*\.[0-9]*\).*/\1/'
}

echo per $(( $count / 100 ))K

report()
{
  echo "$2 $(python -c 'print '$1' / '$count)"
}


report $(timer myfunc 1 23 6) "Function (1) calls: "
report $(timer myfunc2 1 23 6) "Functions (2) calls: "
report $(timer myfunc3 1 23 6) "Function in subshells: "
report $(timer myfunc4 1 23 6) "Functions (2) calls: "



