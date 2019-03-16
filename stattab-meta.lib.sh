#!/bin/sh

stattab_meta_lib_load()
{
  lib_assert statusdir
  test -n "$STMTAB" || STTAB=${STATUSDIR_ROOT}index/stattab-meta.list
}

stattab_meta_lib_init()
{
  test -e "$STMTAB" || {
    mkdir -p "$(dirname "$STMTAB")" && touch "$STMTAB"
  }
}

stattab_meta_load()
{
  for stm_ctx in $@
  do true
  done
}

stattab_meta_define() # Prefix Symbol
{
  test $# -eq 2 -a -n "$1" -a -n "$2" || return 98
  sed \
      -e 's/STTAB/'$2'TAB/' \
      -e 's/sttab/'$(echo $2|tr '[:upper:]' '[:lower:]')'tab/' \
      -e 's/stattab/'$1'tab/' \
      "$scriptpath/stattab.lib.sh"
}
