#!/usr/bin/env bash

#functions_htd_lib_load() {}
#functions_htd_lib_init() {}


functions_find_names_on_path() # [find_ext] ~ <Func-Name-Grep> [<SCRIPTPATH>]
{
  test $# -gt 0 || set -- "^ *[^#].*"
  test $# -gt 1 || set -- "1" "SCRIPTPATH"
  test $# -eq 2 || return 98

  true "${find_ext:=".lib.sh"}"

  for sp in $(eval echo \$$2 | tr ':' ' ')
  do
    functions_grep $1 $sp/*$find_ext
  done

  unset find_ext
}


functions_list_counts()
{
  test $# -gt 0 || set -- "^ *[^#].*"
  test $# -gt 1 || set -- "1" "SCRIPTPATH"
  test $# -eq 2 || return 98

  true "${find_ext:=".lib.sh"}"

  for sp in $(eval echo \$$2 | tr ':' ' ')
  do
    functions_grep $1 $sp/*$find_ext | wc -l | awk '{print $1}'
  done

  #dn=$(dirname "$x")
  #bn=$(basename "$x" .lib.sh)
  #echo $(htd functions list $dn/$bn.lib.sh) $bn

  #for sp in $(eval echo \$$2 | tr ':' ' ')
}
