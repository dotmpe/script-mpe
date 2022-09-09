#!/bin/sh


uriref_lib_load()
{
  # Match Ref-in-Angle-brachets or URL-Ref-Scheme-Path
  uri_re='\(urn:[^ ]\+\|<[_a-zA-Z][_a-zA-Z0-9-]\+:[^> ]\+>\|\(\ \|^\)[_a-zA-Z][_a-zA-Z0-9-]\+:\/\/[^ ]\+\)'
}

uriref_grep () # [SRC|-]
{
  grep -o "$uri_re" "$@" | tr -d '<>"''"' # Remove angle brackets or quotes
}

uriref_list () # <Path>
{
  test $# -eq 1 || return 98
  uriref_grep "$1"
}

uriref_clean_meta ()
{
  tr -d ' {}()<>"'"'"
}

uriref_list_clean ()
{
  test $# -eq 1 || return 98
  local format=$(ext_to_format "$(filenamext "$1")")
  func_exists uriref_clean_$format || format=meta
  uriref_list "$1" | uriref_clean_$format
}

#
