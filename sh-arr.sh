
## Shell/Arr:

# What do you use to check wether a symbol has been declared as array variable?
# there is no 'declare --array-exists'

# So it seems, the only way is declare -p. See also sh-typeset.

# Also, var= makes a variable but arry=() does not make an array
# but ("") does. Oof.

arr=myArray

tt ()
{
    #echo $1: len: ${#arr}
    echo $1: len: ${#myArray[@]} # Why is it 1?
    #echo $1: len: ${#arr[*]}
    echo $1: arith exp: $( (( ${#myArray[@]} )) && echo set || echo unset )
    echo $1: ${!arr[@]-unset}
    echo $1: ${!arr[*]-unset}
    #echo $1: ${myArray-unset}
    #echo $1: ${myArray-unset}
    echo $1: ${myArray[@]-unset}
    echo $1: ${myArray[*]-unset}
}

echo "Nothing set"
tt A

echo
echo "Array declared"
declare -a myArray
declare -p myArray
tt B

echo
echo "Array assigned empty (but still empty or null)"
myArray=()
declare -p myArray
tt C

echo
echo "Array assigned one empty string element (but still empty or null)"
myArray=("")
declare -p myArray
tt C2

echo
echo "Array assigned one word element"
myArray=(foo)
declare -p myArray
tt C3


echo
echo "One more element"
myArray+=(bar)
echo D: len: ${#myArray[*]}
#
