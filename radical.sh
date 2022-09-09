#!/usr/bin/env bash
# Created: 2020-08-13

update ()
{
  radical.py -u full-sh "$@" |
      while IFS='+:' read pref srcf sl ls sc cs _7 _ _8 _ _9 _ _10 _ match
  do
    #echo "$srcf#l$sl+$el ----------------------------------------------------"
    #edl_resolve_line_range $srcf $sl $el || echo E$?

    echo "$srcf#c$sc+$cs -----------------------------------------------------"
    edl_resolve_chars $srcf $sc $cs
  done
}

# Additional output formats and example use of radical and tq
print-tags ()
{
  radical.py -Y json-stream --tags "$@"
}

print-descriptions ()
{
  radical.py --issue-format=full-sh "$@" | grep -v '^\s*$' | tq.py -p "$@"
}

set -euo pipefail
. $(dirname "$0")/edl.lib.sh
true "${U_S:="$HOME/project/user-scripts"}"
. $U_S/src/sh/lib/os.lib.sh
test $# -gt 1 || set -- update $0
"$@"
