
## Shell/Var:

# Typeset helps to scope variables and put some attributes, but
# until assigned they remain unset as if undeclared, even to ${var?unset}
# (and set does not list 'declare but unset' variables either)

# So to use 'declare' (at least as in Bash) seems inappropiate for
# shell variables. Arrays behave in the same way except () is not an empty
# array but ("") is ??? meh.

# Still 'declare -p' provides a script for previously declared variables.
# See sh-typeset

tt ()
{
    echo "Var: ${var+set }${var-unset}"
    echo "And: ${var:-empty}${var:+ not empty}"
}

assert_isset ()
{
  true "${var?}"
}
assert_nonzero ()
{
  true "${var:?}"
}

echo "No var"
tt
echo
echo "Var declared (but still unset)"
declare -- var
declare -p var
tt
echo
echo "Var defined (set to empty str)"
declare -- var=
declare -p var
tt
assert_isset
echo
echo "Again, id."
var=
declare -p var
assert_isset
echo
echo "To empty str, id."
var=""
declare -p var
echo
declare -- var
echo "Redeclare to word"
var=foo
tt
assert_isset && assert_nonzero
unset var
echo
echo "Now declare integer, it auto assigns 0 on empty string"
declare -i var=
declare -p var
tt
#
