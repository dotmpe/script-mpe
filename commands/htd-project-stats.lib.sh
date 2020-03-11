#!/bin/sh

htd_project_stats_lib_load()
{
  lib_assert date project-stats build-htd
  # XXX: statusdir_init && package_lib_init && build_init && project_stats_init
}

htd_project_stats_stat()
{
  test -e "$LIB_LINES_TAB" || warn "No Lib-linecount report" 1
  test -e "$LIB_LINES_COLS" || warn "No Lib-linecount report list" 1

  project_stats_list_summarize "$LIB_LINES_TAB" "$LIB_LINES_COLS"
  project_stats_list "$LIB_LINES_TAB" "" | head -n 7
  echo "... ($(( $(count_lines "$LIB_LINES_TAB" ) - 14 )) items)"
  project_stats_list "$LIB_LINES_TAB" "" | tail -n 7
}

htd_project_stats_list()
{
  project_stats_list "$LIB_LINES_TAB" ""
  project_stats_list_summarize "$LIB_LINES_TAB" "$LIB_LINES_COLS"
}

htd_project_stats_build()
{
  project_stats_lib_size_lines &&
    htd_project_stats_stat
}
