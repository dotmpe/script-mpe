
## Shell/typeset

# Synonym for declare. Because shell typing is somewhat limited, it does not
# really mean declare like someone with background in declarative programming
# would understand it. In particular variables must have a type and an empty
# string value for them to be useful, like in ${var:+} and similar expansions.

# declare -p can be used to check however wheter a symbol has been specified as
# a variable. But being script (although simple) the output does need some str
# manipulation to interpret.

# Because of this, doing any sort of declarative work in shell would benefit
# from having global symbol lookup somehow--like an associative array. But
# even arrays (BASH_REMATCH, MAPFILE, BASH_ARGV, BASH_ARGC) are bit fancy by
# usual shell standards (and certainly not POSIX).

nl ()
{
    typeset -p var
    echo
}
echo NAME var is reference by variable name
typeset -n var
nl
echo And dissapears again
unset var
nl
echo Now is an integer
typeset -i var
nl
echo And also export
typeset -x var
nl
echo And now traces
typeset -t var
nl
var=
echo Can be made readonly
typeset -r var
var=foo
nl

#
