# What is :- and :+ all about. It simple. Three different variables, and three
# states: unset, set empty, and set non-empty.

unset FOO
declare BAR=
declare BAZ=bazval

echo "${FOO:+FOO-colon-plus} ${FOO:-FOO-colon-dash}"
echo "${FOO+FOO-plus} ${FOO-FOO-dash}"

echo "${BAR:+BAR-colon-plus} ${BAR:-BAR-colon-dash}"
echo "${BAR+BAR-plus} ${BAR-BAR-dash}"

echo "${BAZ:+BAZ-colon-plus} ${BAZ:-BAZ-colon-dash}"
echo "${BAZ+BAZ-plus} ${BAZ-BAZ-dash}"

# Which we can summarize into this truth table:
#
#    unset empty nonzero
#  +     0     1       1
# :+     0     0       1
#  -     1     0       1
# :-     1     1       i

# Variables that are only declared but have no empty value assigned appear as
# unset. These fail ?/:? checks as well because obviously they cannot be empty
# if unset. See sh-decl.sh for some thoughts on checking for declarations.
