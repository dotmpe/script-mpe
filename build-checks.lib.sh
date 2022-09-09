#!/bin/sh

# Initialize build-checks settings
build_checks_lib_load()
{
  lib_load build-htd table
}

# Quick test for no (non-id/numered) tags at all
check_clean()
{
  # NOTE: instead of -v, use -sr for resolve/recurse to allow symlinks, dirs;
  # Just invert status at the end.
  grep -srIq '\(XXX\|TODO\|FIXME\):' "$@" && return 1 || return 0
}

grep_dirt()
{
  grep -srI '\(XXX\|TODO\|FIXME\):' "$@"
}

# Assert that each LIST file has a header with var-names.
check_list_headers()
{
  grep_list_header_inner()
  {
    grep -q 'vim:ft=todo.txt' "$1" && return # NOTE: skip outline format
    list_header="$(grep_list_head "$@")" || error "Failed at '$1' $?"
  }
  build_srcfiles '*.list' '*.tab' |
      p='' s='' act=grep_list_header_inner foreach_do
}

check()
{
  check_list_headers
  dirty=$( build_modified | grep_dirt | count_lines )
  test $dirty -eq 0 || warn "$dirty Files tagged dirty"
}
