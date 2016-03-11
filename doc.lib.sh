#!/bin/sh


doc_path_args()
{
  paths=$HTDIR
  test "$(pwd)" = "$HTDIR" || {
    paths="$paths ."
  }
}

doc_find_name()
{
  htd_find_ignores
  match_grep_pattern_test "$(pwd)"
  {
    test -z "$1" \
      && eval "find -L $paths $find_ignores -o \( -type f -o -type l \) -print" \
      || eval "find -L $paths $find_ignores -o -iname $1 -a \( -type f -o -type l \) -print"
  } | grep -v '^'$p_'$' \
    | sed 's/'$p_'\///'
}

doc_grep_content()
{
  test -n "$1" || set -- .
  htd_grep_excludes
  match_grep_pattern_test "$(pwd)/"
  eval "grep -SslrIi '$1' $paths $grep_excludes" \
    | sed 's/'$p_'//'
}


