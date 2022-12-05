#!/usr/bin/env bash

## What ASCII characters does bash allow in function declarations

# Bash naming is very liberal. But spaces, variables are not possible, and
# aliasing is useless. What sorts of symbolic names can be used in namespacing,
# besides the usual Bourne shell [_[:alpha:]][_[:alphanum:]]*?

# Fine: @/^:.,_+-?
# Fine (but syntastic fails): *[]~

# Not possible: &!\%$#=|()'" ie. variables, shell expressions and anything that
# requires string quoting/escaping.


# Surprisingly these are all valid
# sym=[]HERE
# sym=[HERE]
# sym=HERE[]


# Specifically testing initial character but it makes no difference to Bash

sym=?HERE

?HERE ()
{
  echo "there!"
}

?HERE:my-fun ()
{
  echo whoooo
}

type "$sym"
type "$sym:my-fun"
"$sym:my-fun"
"$sym"
#
