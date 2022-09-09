#!/usr/bin/env bash

functions_htd_lib_load()
{
  true "${lib_functions_grep:="[[:alnum:]_-]*"}"
}
#functions_htd_lib_init() {
#  test "${functions_htd_lib_init-}" = "0" && return
#}


functions_find_names() # ~ <Func-Name-Grep> [<SCRIPTSVAR>]
{
  test $# -le 2 || return 98
  test $# -gt 0 -a -n "${1-}" || set -- "$lib_functions_grep" "${2-}"
  test $# -gt 1 -a -n "${2-}" || set -- "$1" "ENV_SRC"

  for sp in $(eval echo \$$2 | tr ':' ' ')
  do
    functions_grep "$1" "$sp"
  done
}


functions_find_names_on_path() # [find_ext] ~ <Func-Name-Grep> [<SCRIPTPATH>]
{
  test $# -le 2 || return 98
  test $# -gt 0 -a -n "${1-}" || set -- "$lib_functions_grep" "${2-}"
  test $# -gt 1 -a -n "${2-}" || set -- "$1" "ENV_SRC"

  true "${find_ext:=".lib.sh"}"

  for sp in $(eval echo \$$2 | tr ':' ' ')
  do
    functions_grep "$1" "$sp"/*"$find_ext"
  done

  unset find_ext
}


functions_list_counts()
{
  test $# -le 2 || return 98
  test $# -gt 0 -a -n "${1-}" || set -- "$lib_functions_grep" "${2-}"
  test $# -gt 1 -a -n "${2-}" || set -- "$1" "ENV_SRC"

  true "${find_ext:=".lib.sh"}"

  for sp in $(eval echo \$$2 | tr ':' ' ')
  do
    functions_grep "$1" "$sp"/*"$find_ext" | wc -l | awk '{print $1}'
  done

  #dn=$(dirname "$x")
  #bn=$(basename "$x" .lib.sh)
  #echo $(htd functions list $dn/$bn.lib.sh) $bn

  #for sp in $(eval echo \$$2 | tr ':' ' ')
}
