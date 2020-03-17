#!/bin/sh


htd_functions_lib_load()
{
  lib_assert functions
}

ht_functions() { htd__functions "$@"; }

htd_man_1__functions='List functions, group, filter, and use `source` to get
source-code info.

   list-functions|list-func|ls-functions|ls-func
     List shell functions in files.
   find-functions Grep Scripts...
     List functions matching grep pattern in files
   list-groups [ Src-Files... ]
     List distinct values for "grp" attribute. See box-list-function-groups.
   list-attr [ Src-Files... ]
     See box-list-functions-attrs.

'
htd_run__functions=iAOl
htd__functions()
{
  test -n "$1" || set -- copy
  case "$1" in

    list|list-functions|list-func|ls-functions|ls-func ) shift ;
        functions_list "$@"
      ;;
    find|grep-name|find-functions ) shift ; functions_grep "$@" ;;
    attrs|list-attr ) shift ; test -n "$1" || warn "Scanning htd script itself"
        box_list_functions_attrs "$@" ;;
    groups|list-groups ) shift ; test -n "$1" || warn "Scanning htd script itself"
        box_list_function_groups "$@"
      ;;
    filter-functions ) shift ; htd__filter_functions "$@" ;;
    diff-function-names ) shift ; htd__diff_function_names "$@" ;;
    list-functions-added|new-functions ) shift
        htd__list_functions_added "$@"
      ;;
    list-functions-removed|deleted-functions ) shift
        htd__list_functions_removed "$@"
      ;;

    ranges ) shift ; functions_ranges "$@" ;;
    filter-ranges ) shift ; functions_filter_ranges "$@" ;;

    * ) s= p= subcmd_prefs=functions_ try_subcmd_prefixes "$@" ;;
	# error "'$1'?" 1 ;;
  esac
}
htd_libs__functions=functions
