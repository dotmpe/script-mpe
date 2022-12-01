
set -euETo pipefail
shopt -s extdebug

test_fun ()
{
  true "${FOO:=$( return 10 )}" || return
  test "$(return 10)" = "blah" || return
  FOO=$( return 11 ) || return
  return 1
}

## Using subshell expressions as parameters causes masking of return state

# false returns non-zero
false || echo 1 E$?

# But here none of the inline expressions in test_fun returned!
test_fun || echo 3 E$?

# Just like this one: echo gets the output value of false, not the status!
echo $(false) || echo 2 E$?

# So do not rely it bc. this returns 1
var=$(false) || echo 4 E$?

# As with this and the other or any more obvious case,
# none of these expressions pass on status!
declare var=$(false) || echo 5 E$?

#
