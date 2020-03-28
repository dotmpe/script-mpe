#!/bin/sh

# Error unless non-empty and trueish
trueish()
{
  test $# -eq 1 -a -n "${1:-}" || return
  case "$1" in
    [Oo]n|[Tt]rue|[Yyj]|[Yy]es|1 )
      return 0;;
    * )
      return 1;;
  esac
}
# Sh-Copy: HT:tools/u-s/parts/trueish.inc.sh
# Sh-Copy-Part: U-S:src/sh/lib/sys.lib.sh

# Id: BIN:tools/sh/parts/trueish.sh
