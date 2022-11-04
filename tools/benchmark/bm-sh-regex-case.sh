
# Looking at how fast a regex test does for a simple two-char check.

# regex 1.7s/100000 = 1.7 ms
# test  1.5s/100000 = 1.5 ms
# case  1.2s/100000 = 1.2 ms

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

source tools/benchmark/_lib.sh
runs=100000
echo -e "\nTesting regex..."; time run_test $runs regex
echo -e "\nTesting test..."; time run_test $runs test
echo -e "\nTesting case..."; time run_test $runs case
