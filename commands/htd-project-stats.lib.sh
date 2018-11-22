#!/bin/sh

htd_project_stats_lib_load()
{
  lib_load date build && package_init && build_init && project_stats_init
}

htd_project_stats_stat()
{
  test -e "$LIB_LINES_TAB" || warn "No Lib-linecount report" 1
  test -e "$LIB_LINES_COLS" || warn "No Lib-linecount report list" 1
  records=$(( $(count_cols "$LIB_LINES_TAB") - 1))
  note "$(count_lines "$LIB_LINES_TAB") lib(s) $records record(s)"
}

htd_project_stats_build()
{
  project_stats_lib_size_lines &&
    htd_project_stats_stat
}
