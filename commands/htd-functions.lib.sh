#!/bin/sh


htd_functions_lib_load()
{
  lib_load functions
}


htd__functions()
{
  test -n "$1" || set -- copy
  case "$1" in

    list|list-functions|list-func|ls-functions|ls-func ) shift ;
        functions_list "$@"
      ;;
    find|find-functions ) shift ; find_functions "$@" ;;
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
    ranges ) shift ; functions_ranges "$@" ;;
    filter-ranges ) shift ; functions_filter_ranges "$@" ;;

    * ) s= p= subcmd_prefs=functions_ try_subcmd_prefixes "$@" ;;
	# error "'$1'?" 1 ;;
  esac
}
