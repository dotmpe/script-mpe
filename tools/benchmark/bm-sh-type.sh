
## Three ways to test a function exists

# test -t seems very systematic, but we need to check its output value.
# declare -F seems more on point. And if we don't care about cmd vs functions
# might as well use command -v. What is the time req for each?

# type -t ...                         100ms ( : 10000 = 0.1us )
# type-t + strcmp                     >4.5s
# command -v                          100ms
# declare -F                          100ms
# which                               >20s
# command-v + str-cmp (fun2)          4.8s
# command-v + cut + strcmp (fun2a)    17s

# Conclusion: test -t combined with string compare is a terrible way to check
# if a shell function has been defined. Any string op should be avoided.

# For sorting out types of callables, command -v will print a path for
# executable files or a name for functions though. It even prints alias
# declarations.

# 'which' of course cannot find a thing (looking on every PATH) and so takes a
# long, long time to complete.

# type -t, command -v and declare -F are much faster than any string operation
# or string editing pipeline.

# TODO: test declare and command to find functions and aliases

source tools/benchmark/_lib.sh

sh_mode strict

runs=10000

test_isfun ()
{
    test "$(type -t "${1:?}")" = "function"
}

test_isfun2 ()
{
    declare v
    v=$(command -v "${1:?}")
    test ${#v} -gt 0 -a "${v:0:1}" != '/'
}
test_isfun2b ()
{
    v=$(command -v "${1:?}" | cut -c 1)
    test ${#v} -gt 0 -a "${v:0:1}" != '/'
}

time run_test_q $runs -- type -t run_test
time run_test $runs -- test_isfun run_test
# Alternative is-function tests:
time run_test_q $runs -- command -v run_test
time run_test_q $runs -- declare -F run_test
#time run_test_q $runs -- which run_test
time run_test_q $runs -- test_isfun2 run_test
time run_test_q $runs -- test_isfun2b run_test
