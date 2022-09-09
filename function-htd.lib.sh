#!/bin/sh

function_help()
{
  local file= grep_line=
  htd_function_comment "$@"
  htd_function_help
}

function_comment()
{
  test -n "$1" || error "name or string-id expected" 1
  htd_function_comment "$@"
}
