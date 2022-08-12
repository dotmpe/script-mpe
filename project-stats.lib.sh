#!/bin/sh


project_stats_lib_load()
{
  lib_assert date statusdir package
}

project_stats_lib_init()
{
  test "${project_stats_init-}" = "0" && return
  project_stats_init && project_stats_req
}


project_stats_req()
{
  test -n "${LIB_LINES_TAB-}" || error "No Lib-linecount report name" 1
  test -n "${LIB_LINES_COLS-}" || error "No Lib-linecount reports list name" 1
}

project_stats_init()
{
  test -n "${LIB_LINES_TAB-}" || {
    LIB_LINES_TAB="${STATUSDIR_ROOT}log/${package_name}-lib-lines.tab"
  }
  test -n "${LIB_LINES_COLS-}" || {
    LIB_LINES_COLS="${STATUSDIR_ROOT}log/${package_name}-lib-lines.list"
  }
}

project_edition()
{
  test -n "$TRAVIS_JOB_NUMBER" && {
    echo "$TRAVIS_COMMIT-$TRAVIS_JOB_NUMBER"
  } || git describe
}

project_stats_lib_size_lines()
{
  test -e "$LIB_LINES_TAB" &&
    set -- "$LIB_LINES_TAB.latest" || set -- "$LIB_LINES_TAB"

  record_nr=$(count_cols "$LIB_LINES_TAB")
  echo "$(project_edition) $( datet_isomin )" >>"$LIB_LINES_COLS"

  printf "#Lib-Line_Count\t$record_nr\n" >"$@"
  expand_spec_src libs | p= s= act=count_lines foreach_addcol >>"$@"

  fnmatch "*.latest" "$1" || return 0

  project_stats_lib_size_lines_merge "$LIB_LINES_TAB.latest"
}

project_stats_lib_size_lines_merge()
{
  cat "$LIB_LINES_TAB" "$1" | join_lines - '\t' >"$LIB_LINES_TAB.tmp"

  {
      grep '^#Lib-Line_Count\t' "$LIB_LINES_TAB.tmp"
      grep -v '^#Lib-Line_Count\t' "$LIB_LINES_TAB.tmp" | sort

  } >"$LIB_LINES_TAB"

  rm "$1" "$LIB_LINES_TAB.tmp"
}

project_stats_list() # TAB LOGNUM
{
  test -n "$1" || set -- "$LIB_LINES_TAB" "$2"
  test -f "$1" || error "Tab expected '$1'" 1
  test -n "$2" || set -- "$1" $(count_cols "$1")

  local tab="$1" col="$2"
  filter_content_lines "$1" | while read file stats
  do
    set -- "" $stats
    eval "echo \"\$$col\" $file"
  done | sort -rn
}

project_stats_list_summarize()
{
  last_record_num=$(( $(count_cols "$1") - 1))
  note "$(count_lines "$1") lib(s) $last_record_num record(s)"
  note "Last record ($last_record_num): $( tail -n 1 "$2" )"
}
