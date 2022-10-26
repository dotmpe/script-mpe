
# Looking at how fast a regex test does for a simple two-char check.


# regex 1.7s/100000 = 17 microseconds
# test  1.5s/100000 = 15 microseconds
# case  1.2s/100000 = 12 microseconds


test_regex ()
{
  [[ "abc" =~ ^[az]$ ]]
}

test_test ()
{
  #test "abc" = "a" -o "abc" = "z"
  test "abc" = "a" || test "abc" = "z"
}

test_case ()
{
  case "abc" in
      ( a ) true ;;
      ( z ) true ;;
      ( * ) false ;;
  esac
}

run_test ()
{
  local iter=${1:?}
  shift || return
  while test "$iter" -gt "0"
  do
    test_${1:?} || true
    iter=$(( $iter - 1 ))
  done
}

runs=100000
echo -e "\nTesting regex..."
time run_test $runs regex
echo -e "\nTesting test..."
time run_test $runs test
echo -e "\nTesting case..."
time run_test $runs case
